#git-pulls

http://github.com/schacon/git-pulls

[![Gem Version](https://badge.fury.io/rb/comma.png)](http://badge.fury.io/rb/git-pulls)

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

    $ git pulls checkout
    Checking out all open pull requests for schacon/git-reference
    > feature-request-1 into pull-feature-request-1
    > feature/request2 into pull-feature/request2

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

##Requirements

`git-pulls` assumes you're using an 'origin' remote.  If you are not,
either add an 'origin' remote that points to the GitHub repository you want to check
for pull requests, or set the name of your remote via an environment
variable, GIT_REMOTE.

##Private repositories

To manage pull requests for your private repositories you have set up your git config for github

    $ git config --global github.user your_gitubusername
    $ git config --global github.token your_githubtoken123456789

You must generate your OAuth token for command line use, see how to [generate oauth token](https://help.github.com/articles/creating-an-oauth-token-for-command-line-use).

##Using git-pulls with GitHub Enterprise

If you want to use the git-pulls script with a private GitHub install, set the
github.host config value to your internal host.

    $ git config --global github.host https://github.mycompany.com
    $ git config --global github.api https://github.mycompany.com/api/v3

##Installation

Simply install it via Rubygems:

    gem install git-pulls

(Prefix with `sudo` if necessary)

via Docker:

Use it as a container by building it first

    docker build -t git-pulls .

And then launch the command like this :

    docker run -v `pwd`:/app -v ~/.gitconfig:/root/.gitconfig --rm -it git-pulls list

##TESTING

To run the test suite use the following command :

```Bash

bundle install
bundle exec rake test

```
