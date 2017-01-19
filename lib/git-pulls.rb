require 'rubygems'
require 'json'
require 'date'
require 'launchy'
require 'octokit'
require 'psych'

class GitPulls

  GIT_REMOTE = ENV['GIT_REMOTE'] || 'origin'
  GIT_PATH = lambda { return `git rev-parse --git-dir`.chomp }
  PULLS_CACHE_FILE = "#{GIT_PATH.call}/pulls_cache.yml"

  def initialize(args)
    @command = args.shift
    @user, @repo = repo_info
    @args = args
  end

  def self.start(args)
    GitPulls.new(args).run
  end

  def run
    configure
    if not @user
      not_a_github_repository
    elsif @command && self.respond_to?(@command)
      # If the cache file doesn't exist, make sure we run update
      # before any other command. git-pulls will otherwise crash
      # with an exception.
      update unless File.exists?(PULLS_CACHE_FILE) || @command == 'update'

      self.send @command
    elsif %w(-h --help).include?(@command)
      usage
    else
      help
    end
  end

  ## COMMANDS ##

  def help
    puts "No command: #{@command}"
    puts "Try: update, list, show, merge, checkout, browse"
    puts "or call with '-h' for usage information"
  end

  def not_a_github_repository
    puts "No user informations found. Make sure you're in a Github's repository."
  end

  def usage
    puts <<-USAGE
Usage: git pulls update
   or: git pulls list [state] [--reverse]
   or: git pulls show <number> [--comments] [--full]
   or: git pulls browse <number>
   or: git pulls merge <number> [--no-commit] [--log]
   or: git pulls checkout [--force]
    USAGE
  end

  def merge
    num = @args.shift
    option = @args.shift
    if pull = pull_num(num)
      head = pull[:head].to_hash
      user = pull[:user].to_hash

      if repo = head[:repo] && head[:repo].to_hash
        owner     = repo[:owner].to_hash
        repo_name = repo[:name]

        sha = head[:sha]

        message = "Merge pull request ##{num} from #{owner[:login]}/#{repo_name}\n\n---\n\n"
        message += pull[:body] ? pull[:body].gsub("'", '') : ""
        cmd = ''
        if option == '--log'
          message += "\n\n---\n\nMerge Log:\n"
          puts cmd = "git merge --no-ff --log -m '#{message}' #{sha}"
        elsif option == '--no-commit'
          message += "\n\n---\n\nMerge with --no-commit option:\n"
          puts cmd = "git merge --no-commit -m '#{message}' #{sha}"
        else
          puts cmd = "git merge --no-ff -m '#{message}' #{sha}"
        end
        exec(cmd)

      else # they deleted the source repo
        owner     = head[:user].to_hash[:login]
        patch_url = "#{pull[:_links].to_hash[:html].to_hash[:href]}.patch"

        puts "Sorry, #{owner} deleted the source repository, git-pulls doesn't support this."
        puts "You can manually patch your repo by running:"
        puts
        puts "  curl #{patch_url} | git am"
        puts
        puts "Tell the contributor not to do this."
        return false
      end
    else
      puts "No such number"
    end
  end

  def show
    num = @args.shift
    optiona = @args.shift
    optionb = @args.shift

    if pull = pull_num(num)
      head = pull[:head].to_hash
      repo = head[:repo].to_hash
      user = pull[:user].to_hash

      comments = []
      if optiona == '--comments' || optionb == '--comments'
        i_comments = Octokit.issue_comments("#{@user}/#{@repo}", num).map(&:to_hash)
        p_comments = Octokit.pull_request_comments("#{@user}/#{@repo}", num).map(&:to_hash)
        c_comments = Octokit.commit_comments(repo[:full_name], head[:sha])
        comments = (i_comments | p_comments | c_comments).sort_by {|i| i[:created_at]}
      end
      puts "Number   : #{pull[:number]}"
      puts "Label    : #{head[:label]}"
      puts "Status   : #{pull[:state]}"
      puts "Creator  : #{user[:login]}"
      puts "Created  : #{pull[:created_at]}"
      puts
      puts "Title    : #{pull[:title]}"
      puts
      puts pull[:body]
      puts
      puts '------------'
      puts
      comments.each do |comment|
        user = comment[:user]

        puts "Comment  : #{user[:login]}"
        puts "Created  : #{comment[:created_at]}"
        puts "File     : #{comment[:path]}:L#{comment[:line] || comment[:position] || comment[:original_position]}" unless comment[:path].nil?
        puts
        puts comment[:body]
        puts
        puts '------------'
        puts
      end
      if optiona == '--full' || optionb == '--full'
        exec "git diff --color=always HEAD...#{head[:sha]}"
      else
        puts "cmd: git diff HEAD...#{head[:sha]}"
        puts git("diff --stat --color=always HEAD...#{head[:sha]}")
      end
    else
      puts "No such number"
    end
  end

  def browse
    num = @args.shift
    if pull = pull_num(num)
      Launchy.open(pull[:_links].to_hash[:html].to_hash[:href])
    else
      puts "No such number"
    end
  end

  def list
    state = @args.shift

    if not ['open', 'closed'].include?(state)
      state = 'open'
      option = state
    else
      option = @args.shift
    end

    puts state.capitalize + " Pull Requests for #{@user}/#{@repo}"
    pulls = state == 'open' ? get_open_pull_info : get_closed_pull_info

    if (state == 'closed')
       pulls.sort! { |a, b| b[:closed_at] <=> a[:closed_at] }
    end

    pulls.reverse! if option == '--reverse'

    pulls.each do |pull|
      pull = pull.to_hash
      head = pull[:head].to_hash

      line = []
      line << l(pull[:number], 4)
      line << l(Date.parse(pull[:created_at].to_s).strftime("%m/%d"), 5)
      line << l(pull[:title], 35)
      line << l(head[:label], 50)

      puts line.join ' '
    end
    if pulls.count == 0
      puts ' -- no ' + state + ' pull requests --'
    end
  end

  def checkout
    puts "Checking out all open pull requests for #{@user}/#{@repo}"
    pulls = get_open_pull_info
    pulls.each do |pull|
      head        = pull[:head].to_hash
      branch_ref  = head[:ref]

      puts "> #{branch_ref} into pull-#{branch_ref}"
      git("branch --track #{@args.join(' ')} pull-#{branch_ref} #{GIT_REMOTE}/#{branch_ref}")
    end
  end

  def update
    puts "Updating #{@user}/#{@repo}"
    cache_pull_info
    fetch_stale_forks
    list
  end

  def fetch_stale_forks
    puts "Checking for forks in need of fetching"

    pulls = get_open_pull_info | get_closed_pull_info
    repos = {}
    pulls.each do |pull|
      head = pull[:head].to_hash

      unless repo = head[:repo] && head[:repo].to_hash
        next # Fork has been deleted
      end

      owner     = repo[:owner].to_hash
      repo_name = repo[:name]
      sha       = head[:sha]

      unless has_sha?(sha)
        repo        = "#{owner[:login]}/#{repo_name}"
        repos[repo] = true
      end
    end
    if github_credentials_provided?
      endpoint = "git@github.com:"
    else
      endpoint = github_endpoint + "/"
    end
    repos.each do |repo, bool|
      puts "  fetching #{repo}"
      git("fetch #{endpoint}#{repo}.git +refs/heads/*:refs/pr/#{repo}/*")
    end
  end

  def has_sha?(sha)
    git("show #{sha} 2>&1")
    $?.exitstatus == 0
  end

  def not_merged?(sha)
    commits = git("rev-list #{sha} ^HEAD 2>&1")
    commits.split("\n").size > 0
  end

  # DISPLAY HELPER FUNCTIONS #

  def l(info, size)
    clean(info)[0, size].ljust(size)
  end

  def r(info, size)
    clean(info)[0, size].rjust(size)
  end

  def clean(info)
    info.to_s.gsub("\n", ' ')
  end

  # PRIVATE REPOSITORIES ACCESS

  def configure
    Octokit.configure do |config|

      config.login        = github_login if github_login and not github_login.empty?
      config.web_endpoint = github_endpoint
      config.access_token = github_token if github_token and not github_token.empty?
      config.proxy        = github_proxy if github_proxy and not github_proxy.empty?
      config.api_endpoint = github_api_endpoint if (github_api_endpoint and \
                                                not github_api_endpoint.empty?)
    end
  end

  def github_login
    git("config --get-all github.user")
  end

  def github_token
    git("config --get-all github.token")
  end

  def github_endpoint
    host = git("config --get-all github.host")
    if host.size > 0
      host
    else
      'https://github.com'
    end
  end
  def github_api_endpoint
    endpoint = git("config --get-all github.api")
    if endpoint.size > 0
      endpoint
    else
      'https://api.github.com'
    end

  end

  def github_proxy
    git("config --get-all http.proxy")
  end

  # API/DATA HELPER FUNCTIONS #

  def github_credentials_provided?
    if github_token.empty? && github_login.empty?
      return false
    end
    true
  end

  def get_closed_pull_info
    get_data(PULLS_CACHE_FILE)['closed'].map(&:to_hash)
  end

  def get_open_pull_info
    get_data(PULLS_CACHE_FILE)['open'].map(&:to_hash)
  end

  def get_data(file)
    ::Psych.load_file(file)
  end

  def cache_pull_info
    response_o = Octokit.pull_requests("#{@user}/#{@repo}", state: 'open')
    response_c = Octokit.pull_requests("#{@user}/#{@repo}", state: 'closed')
    save_data({'open' => response_o, 'closed' => response_c}, PULLS_CACHE_FILE)
  end

  def save_data(data, file)
    File.open(file, "w+") do |f|
      f.puts Psych.dump(data)
    end
  end

  def pull_num(num)
    pull = get_open_pull_info.select { |p| p[:number].to_s == num.to_s }.first
    pull ||= get_closed_pull_info.select { |p| p[:number].to_s == num.to_s }.first
    pull
  end

  def github_insteadof_matching(c, u)
    first = c.collect {|k,v| [v, /url\.(.*github\.com.*)\.insteadof/.match(k)]}
             .find {|v,m| v and u.index(v) and m != nil}

    if first
      return first[0], first[1][1]
    end
    return nil, nil
  end

  def github_user_and_proj(u)
    # Trouble getting optional ".git" at end to work, so put that logic below
    m = /github\.com.(.*?)\/(.*)/.match(u)
    if m
      return m[1], m[2].sub(/\.git\Z/, "")
    end

    # that works with default github but not enterprise
    return enterprise_user_and_proj(u)
  end

  def enterprise_user_and_proj(u)
    # if git, u is probably something like: git@github.hq.corp.lan:SomeGroup/some_repo.git
    m = /.*?:(.*)\/(.*)/.match(u) if u =~ /^git/

    # if http(s), u is probably something like: https://github.hq.corp.lan/SomeGroup/some_repo.git
    m = /https?:\/\/.*?\/(.*)\/(.*)/.match(u) if u =~ /^http/
    if m
      return m[1], m[2].sub(/\.git\Z/, "")
    end
    return nil, nil
  end

  def repo_info
    c = {}
    config = git('config --list')
    config.split("\n").each do |line|
      k, v = line.split('=')
      c[k] = v
    end
    u = c["remote.#{GIT_REMOTE}.url"]

    user, proj = github_user_and_proj(u)
    if !(user and proj)
      short, base = github_insteadof_matching(c, u)
      if short and base
        u = u.sub(short, base)
        user, proj = github_user_and_proj(u)
      end
    end
    [user, proj]
  end

  def git(command)
    `git #{command}`.chomp
  end
end
