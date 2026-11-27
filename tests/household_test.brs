sub testOneHouseholdAsksNothing()
    assertEqual(householdChoices({ token: "t", me: {} }).Count(), 0, "no households")
    assertEqual(householdChoices({ token: "t", me: {}, households: [{ id: 1, name: "Jo's household" }] }).Count(), 0, "one household")
end sub

sub testTheOwnHouseholdComesFirstAndTheRestAreVisiting()
    choices = householdChoices({ token: "t", me: {}, households: [{ id: 4, name: "Jo's household" }, { id: 9, name: "Mark's household" }, { id: 2, name: "Sam's household" }] })
    assertEqual(choices.Count(), 3)
    assertEqual(choices[0].id, 4)
    assertEqual(choices[0].name, "Jo's household")
    assertEqual(choices[0].label, "Yours")
    assertEqual(choices[1].id, 9)
    assertEqual(choices[1].label, "Visiting")
    assertEqual(choices[2].label, "Visiting")
end sub
