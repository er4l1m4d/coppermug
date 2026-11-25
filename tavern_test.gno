package coppermug

import (
	"strings"
	"testing"

	"gno.land/p/nt/testutils/v0"
)

// reset clears realm state so each test starts from a quiet room.
func reset() {
	seats = map[string]*Adventurer{}
	byName = map[string]string{}
	feed = nil
	recent = nil
	nextPostID = 0
	rollSeq = 0
}

func TestJoin(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(10)

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	addr := testutils.TestAddress("alice").String()
	Join(cross(cur), "Mira", "mage")

	a, ok := seats[addr]
	if !ok {
		t.Fatal("seat was not created")
	}
	if a.Name != "Mira" || a.Class != Mage {
		t.Fatalf("unexpected adventurer: %+v", a)
	}
	if a.Gold != StartingGold {
		t.Fatalf("expected %d gold, got %d", StartingGold, a.Gold)
	}
	if len(feed) != 1 || feed[0].Kind != "join" {
		t.Fatal("join should leave one post on the board")
	}
	if byName["mira"] != addr {
		t.Fatal("name index was not populated")
	}
}

func TestNamesAreCaseInsensitive(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	if byName[strings.ToLower("MIRA")] != byName["mira"] {
		t.Fatal("lookup should be case-insensitive")
	}
}

func TestSayCooldownAndSanitizing(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(100)
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "bard")

	Say(cross(cur), "  first\nround\tis on me  ")
	if len(feed) != 2 {
		t.Fatalf("expected 2 posts, got %d", len(feed))
	}
	if feed[1].Text != "first round is on me" {
		t.Fatalf("text was not flattened: %q", feed[1].Text)
	}

	testing.SetHeight(106)
	Say(cross(cur), "second round")
	if len(feed) != 3 {
		t.Fatalf("cooldown should have expired, got %d posts", len(feed))
	}
}

func TestTip(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(20)
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	Join(cross(cur), "Bram", "fighter")

	left := Tip(cross(cur), "Mira", 25)
	if left != 75 {
		t.Fatalf("expected 75 gold left, got %d", left)
	}
	mira := seats[byName["mira"]]
	if mira.Gold != 125 || mira.Rep != 2 {
		t.Fatalf("unexpected recipient state: gold=%d rep=%d", mira.Gold, mira.Rep)
	}
	if feed[len(feed)-1].Kind != "tip" {
		t.Fatal("tip should be recorded on the board")
	}
}

func TestCheer(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(30)
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	Say(cross(cur), "the cellar door is open")

	var miraPost int64
	for _, p := range feed {
		if p.Author == byName["mira"] {
			miraPost = p.ID
		}
	}

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	Join(cross(cur), "Bram", "rogue")
	Cheer(cross(cur), miraPost)

	if seats[byName["mira"]].Rep != 1 {
		t.Fatal("cheering should give the author renown")
	}
	if len(feed[1].Cheers) != 1 {
		t.Fatal("cheer was not recorded on the post")
	}
}

func TestBuyRound(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(40)
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "bard")
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	Join(cross(cur), "Bram", "fighter")
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("carol")))
	Join(cross(cur), "Sable", "rogue")

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	served, left := BuyRound(cross(cur))
	if served != 2 {
		t.Fatalf("expected 2 neighbours served, got %d", served)
	}
	if left != StartingGold-RoundCost {
		t.Fatalf("expected %d gold left, got %d", StartingGold-RoundCost, left)
	}
	if seats[byName["bram"]].Gold != StartingGold+RoundShare {
		t.Fatal("neighbour did not receive a share")
	}
	if seats[byName["mira"]].Rep != 1 {
		t.Fatal("buyer should gain renown")
	}
}

func TestCupBustOrHold(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(50)
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	a := seats[byName["mira"]]

	OpenCup(cross(cur), 50)
	if a.Gold != 50 || !a.InCup || a.Pot != 50 {
		t.Fatalf("bad cup state after open: gold=%d inCup=%v pot=%d", a.Gold, a.InCup, a.Pot)
	}

	busted := false
	for i := 0; i < 20; i++ {
		die, pot, b := Roll(cross(cur))
		if die < 1 || die > 6 {
			t.Fatalf("die out of range: %d", die)
		}
		if b {
			busted = true
			if pot != 0 || a.InCup {
				t.Fatal("bust should end the run with an empty pot")
			}
			break
		}
		if pot < 50 {
			t.Fatalf("pot should never fall below the stake, got %d", pot)
		}
		if len(a.CupDice) != i+1 {
			t.Fatal("dice history out of sync")
		}
	}

	if busted {
		if a.Gold != 50 {
			t.Fatalf("busted run should leave 50 gold, got %d", a.Gold)
		}
		if a.Losses != 1 {
			t.Fatal("bust should count as a loss")
		}
		return
	}

	pot := a.Pot
	payout, gold := Hold(cross(cur))
	if payout != pot || gold != 50+pot {
		t.Fatalf("bad payout: payout=%d gold=%d", payout, gold)
	}
	if a.InCup || a.Pot != 0 || a.Stake != 0 {
		t.Fatal("hold should clear the cup")
	}
}

func TestCupHoldWins(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(60)
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	a := seats[byName["mira"]]

	// Play small cups until one survives a single roll, then hold.
	for attempt := 0; attempt < 40; attempt++ {
		testing.SetHeight(60 + int64(attempt))
		OpenCup(cross(cur), 10)
		_, _, busted := Roll(cross(cur))
		if busted {
			continue
		}
		pot := a.Pot
		payout, gold := Hold(cross(cur))
		if payout != pot {
			t.Fatalf("payout %d should equal pot %d", payout, pot)
		}
		if gold != a.Gold {
			t.Fatal("gold and payout disagree")
		}
		if payout > 10 {
			if a.Wins != 1 {
				t.Fatal("profitable hold should count as a win")
			}
			if a.BestPot != payout {
				t.Fatal("best pot was not updated")
			}
			return
		}
	}
	t.Skip("no surviving roll in 40 attempts")
}

func TestRollIsDeterministicForSameInputs(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(70)

	rollSeq = 0
	first := rollDie("g1fixed")
	rollSeq = 0
	second := rollDie("g1fixed")
	if first != second {
		t.Fatalf("same inputs should give the same die: %d vs %d", first, second)
	}
	if first < 1 || first > 6 {
		t.Fatalf("die out of range: %d", first)
	}
}

func TestFeedIsBounded(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(100)
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "bard")

	h := int64(100)
	for i := 0; i < MaxFeed+20; i++ {
		h += SayCooldown
		testing.SetHeight(h)
		Say(cross(cur), "line")
	}
	if len(feed) != MaxFeed {
		t.Fatalf("feed should hold %d posts, got %d", MaxFeed, len(feed))
	}
	if feed[len(feed)-1].ID <= feed[0].ID {
		t.Fatal("post ids should keep increasing")
	}
}

func TestTopSeatsIsDeterministic(t *testing.T) {
	reset()
	seats["a"] = &Adventurer{Name: "Zed", Gold: 50}
	seats["b"] = &Adventurer{Name: "Abe", Gold: 50}
	seats["c"] = &Adventurer{Name: "Mira", Gold: 90}

	rows := topSeats(0, 3)
	if len(rows) != 3 {
		t.Fatalf("expected 3 rows, got %d", len(rows))
	}
	if rows[0].Name != "Mira" || rows[1].Name != "Abe" || rows[2].Name != "Zed" {
		t.Fatalf("unexpected order: %s, %s, %s", rows[0].Name, rows[1].Name, rows[2].Name)
	}
}

func TestJoinValidation(cur realm, t *testing.T) {
	reset()
	alice := testutils.TestAddress("alice").String()
	bob := testutils.TestAddress("bob").String()

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")

	cases := []struct {
		addr  string
		name  string
		class string
		want  string
	}{
		{alice, "Mira", "rogue", "you already have a stool here"},
		{bob, "mira", "rogue", "that name is already behind the bar"},
		{bob, "M", "rogue", "name is too short (2 characters minimum)"},
		{bob, "Mira!", "rogue", "names may only use letters, digits, spaces, - and _"},
		{bob, "Bram", "wizard", "unknown class: pick fighter, rogue, mage or bard"},
	}
	for _, c := range cases {
		if got := joinErr(c.addr, c.name, c.class); got != c.want {
			t.Fatalf("joinErr(%q, %q, %q) = %q, want %q", c.addr, c.name, c.class, got, c.want)
		}
	}
	if msg := joinErr(bob, "Bram", "fighter"); msg != "" {
		t.Fatalf("valid join rejected: %s", msg)
	}
}

func TestSayValidation(cur realm, t *testing.T) {
	reset()
	testing.SetHeight(100)
	alice := testutils.TestAddress("alice").String()
	bob := testutils.TestAddress("bob").String()

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "bard")
	Say(cross(cur), "first")

	if got := sayErr(alice, 104); got != "easy there: one tale every few blocks" {
		t.Fatalf("unexpected cooldown message: %q", got)
	}
	if got := sayErr(alice, 105); got != "" {
		t.Fatalf("cooldown should have expired: %q", got)
	}
	if got := sayErr(bob, 200); got != "no stool yet: call Join first" {
		t.Fatalf("unexpected unseated message: %q", got)
	}
	if _, msg := cleanText("   "); msg != "say something first" {
		t.Fatalf("unexpected empty message: %q", msg)
	}
	if _, msg := cleanText(strings.Repeat("a", MaxPostLen+1)); msg != "that tale is too long (240 characters maximum)" {
		t.Fatalf("unexpected long message: %q", msg)
	}
}

func TestTipValidation(cur realm, t *testing.T) {
	reset()
	alice := testutils.TestAddress("alice").String()
	carol := testutils.TestAddress("carol").String()

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	Join(cross(cur), "Bram", "fighter")

	cases := []struct {
		from   string
		to     string
		amount int64
		want   string
	}{
		{alice, "Mira", 10, "you cannot tip yourself; the house is watching"},
		{alice, "Nobody", 10, "nobody by that name is sitting here"},
		{alice, "Bram", 1000, "you cannot tip gold you do not have"},
		{alice, "Bram", 0, "a tip has to be worth something"},
		{alice, "Bram", -5, "a tip has to be worth something"},
		{carol, "Bram", 10, "no stool yet: call Join first"},
	}
	for _, c := range cases {
		if _, got := tipCheck(c.from, c.to, c.amount); got != c.want {
			t.Fatalf("tipCheck(%q, %q, %d) = %q, want %q", c.from, c.to, c.amount, got, c.want)
		}
	}
	if _, msg := tipCheck(alice, "Bram", 10); msg != "" {
		t.Fatalf("valid tip rejected: %s", msg)
	}
}

func TestCheerValidation(cur realm, t *testing.T) {
	reset()
	alice := testutils.TestAddress("alice").String()
	bob := testutils.TestAddress("bob").String()

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	Say(cross(cur), "the cellar door is open")
	postID := feed[len(feed)-1].ID

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	Join(cross(cur), "Bram", "rogue")

	if _, msg := cheerCheck(alice, postID+100); msg != "that tale has already left the board" {
		t.Fatalf("unexpected missing-post message: %q", msg)
	}
	if _, msg := cheerCheck(alice, postID); msg != "you cannot cheer your own tale" {
		t.Fatalf("unexpected own-post message: %q", msg)
	}

	Cheer(cross(cur), postID)
	if _, msg := cheerCheck(bob, postID); msg != "you already cheered that one" {
		t.Fatalf("unexpected duplicate message: %q", msg)
	}
}

func TestRoundValidation(cur realm, t *testing.T) {
	reset()
	alice := testutils.TestAddress("alice").String()
	bob := testutils.TestAddress("bob").String()

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "bard")
	seats[alice].Gold = 5

	if msg := roundErr(alice); msg != "a round costs 25 gold and you are short" {
		t.Fatalf("unexpected short message: %q", msg)
	}
	if msg := roundErr(bob); msg != "no stool yet: call Join first" {
		t.Fatalf("unexpected unseated message: %q", msg)
	}
}

func TestCupValidation(cur realm, t *testing.T) {
	reset()
	alice := testutils.TestAddress("alice").String()
	bob := testutils.TestAddress("bob").String()

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")

	if msg := openCupErr(alice, 5); msg != "the minimum stake is 10 gold" {
		t.Fatalf("unexpected minimum message: %q", msg)
	}
	if msg := openCupErr(alice, 500); msg != "you cannot stake gold you do not have" {
		t.Fatalf("unexpected overdraft message: %q", msg)
	}
	if msg := openCupErr(bob, 50); msg != "no stool yet: call Join first" {
		t.Fatalf("unexpected unseated message: %q", msg)
	}

	OpenCup(cross(cur), 50)
	if msg := openCupErr(alice, 10); msg != "your cup is already on the table: roll or hold" {
		t.Fatalf("unexpected open-cup message: %q", msg)
	}
	if msg := holdErr(alice); msg != "roll at least once before you hold" {
		t.Fatalf("unexpected hold message: %q", msg)
	}

	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("bob")))
	Join(cross(cur), "Bram", "rogue")
	if msg := rollErr(bob); msg != "no cup on the table: call OpenCup first" {
		t.Fatalf("unexpected roll message: %q", msg)
	}
}

func TestNamesWithSpaces(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Old Tom", "bard")

	home := Render(cross(cur), "")
	if !strings.Contains(home, "u/Old%20Tom") {
		t.Fatal("profile link should encode spaces")
	}
	profile := Render(cross(cur), "u/Old%20Tom")
	if !strings.Contains(profile, "Old Tom") || !strings.Contains(profile, "Bard") {
		t.Fatal("encoded profile path should resolve")
	}
}

func TestRenderPages(cur realm, t *testing.T) {
	reset()
	testing.SetRealm(testing.NewUserRealm(testutils.TestAddress("alice")))
	Join(cross(cur), "Mira", "mage")
	Say(cross(cur), "welcome to the mug")

	home := Render(cross(cur), "")
	if !strings.Contains(home, "Copper Mug") || !strings.Contains(home, "1 adventurer") {
		t.Fatal("home page is missing its header or stats")
	}
	if !strings.Contains(home, "u/Mira") {
		t.Fatal("home page should link to profiles")
	}

	feedPage := Render(cross(cur), "feed")
	if !strings.Contains(feedPage, "welcome to the mug") {
		t.Fatal("feed page is missing the post")
	}
	if !strings.Contains(feedPage, "$help&func=Cheer&postID=2") {
		t.Fatal("feed page is missing cheer links")
	}

	board := Render(cross(cur), "board")
	if !strings.Contains(board, "Richest") || !strings.Contains(board, "Mira") {
		t.Fatal("board page is missing rankings")
	}

	cup := Render(cross(cur), "cup")
	if !strings.Contains(cup, "The Cup") || !strings.Contains(cup, "Fairness") {
		t.Log(cup)
		t.Fatal("cup page is missing rules or fairness note")
	}

	profile := Render(cross(cur), "u/mira")
	if !strings.Contains(profile, "Mira") || !strings.Contains(profile, "Renown") {
		t.Fatal("profile page is missing stats")
	}

	rules := Render(cross(cur), "rules")
	if !strings.Contains(rules, "House rules") {
		t.Fatal("rules page is missing")
	}

	missing := Render(cross(cur), "u/nobody")
	if !strings.Contains(missing, "No such room") {
		t.Fatal("unknown profile should 404")
	}
}
