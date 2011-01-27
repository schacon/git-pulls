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
    
Private repositories
----------------

To manage pull requests for your private repositories you have set up your git config for github 

    $ git config --global github.user your_gitubusername
    $ git config --global github.token your_githubtoken123456789
    
You can find your API token on the [account](https://github.com/account) page.


Installation
===============

Simply install it via Rubygems:

    gem install git-pulls

(Prefix with `sudo` if necessary)