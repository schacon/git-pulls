git-pulls
==============

Makes it easy to list and merge GitHub pull requests.

    $ git pulls update
    [fetches needed data for all pull requests]

    $ git pulls list
    Open Pull Requests for schacon/git-reference
    19   10/26 0  Fix tag book link    ComputerDruid:fix-ta
    18   10/21 0  Some typos fixing.   mashingan:master    
    
    $ git pulls list --reverse
    Open Pull Requests for schacon/git-reference
    18   10/21 0  Some typos fixing.   mashingan:master    
    19   10/26 0  Fix tag book link    ComputerDruid:fix-ta

    $ git pulls show 1
    > [summary]
    > [diffstat]

    $ git pulls show 1 --full
    > [summary]
    > [full diff]

    $ git pulls browse 1
    > go to web page (mac only)

    $ git pulls merge 1
    > merge pull request #1

