require 'rubygems'
require 'json'
require 'date'
require 'launchy'
require 'octokit'

class GitPulls

  GIT_REMOTE = ENV['GIT_REMOTE'] || 'origin'
  GIT_PATH = lambda { return `git rev-parse --git-dir`.chomp }
  PULLS_CACHE_FILE = "#{GIT_PATH.call}/pulls_cache.json"

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
   or: git pulls merge <number>
   or: git pulls checkout [--force]
    USAGE
  end

  def merge
    num = @args.shift
    option = @args.shift
    if p = pull_num(num)
      if p['head']['repository']
        o = p['head']['repository']['owner']
        r = p['head']['repository']['name']
      else # they deleted the source repo
        o = p['head']['user']['login']
        purl = p['patch_url']
        puts "Sorry, #{o} deleted the source repository, git-pulls doesn't support this."
        puts "You can manually patch your repo by running:"
        puts
        puts "  curl #{purl} | git am"
        puts
        puts "Tell the contributor not to do this."
        return false
      end
      s = p['head']['sha']

      message = "Merge pull request ##{num} from #{o}/#{r}\n\n---\n\n"
      message += p['body'].gsub("'", '')
      cmd = ''
      if option == '--log'
        message += "\n\n---\n\nMerge Log:\n"
        puts cmd = "git merge --no-ff --log -m '#{message}' #{s}"
      else
        puts cmd = "git merge --no-ff -m '#{message}' #{s}"
      end
      exec(cmd)
    else
      puts "No such number"
    end
  end

  def show
    num = @args.shift
    optiona = @args.shift
    optionb = @args.shift
    if p = pull_num(num)
      comments = []
      if optiona == '--comments' || optionb == '--comments'
        i_comments = Octokit.issue_comments("#{@user}/#{@repo}", num)
        p_comments = Octokit.pull_request_comments("#{@user}/#{@repo}", num)
        c_comments = Octokit.commit_comments(p['head']['repo']['full_name'], p['head']['sha'])
        comments = (i_comments | p_comments | c_comments).sort_by {|i| i['created_at']}
      end
      puts "Number   : #{p['number']}"
      puts "Label    : #{p['head']['label']}"
      puts "Creator  : #{p['user']['login']}"
      puts "Created  : #{p['created_at']}"
      puts
      puts "Title    : #{p['title']}"
      puts
      puts p['body']
      puts
      puts '------------'
      puts
      comments.each do |c|
        puts "Comment  : #{c['user']['login']}"
        puts "Created  : #{c['created_at']}"
        puts "File     : #{c['path']}:L#{c['line'] || c['position'] || c['original_position']}" unless c['path'].nil?
        puts
        puts c['body']
        puts
        puts '------------'
        puts
      end
      if optiona == '--full' || optionb == '--full'
        exec "git diff --color=always HEAD...#{p['head']['sha']}"
      else
        puts "cmd: git diff HEAD...#{p['head']['sha']}"
        puts git("diff --stat --color=always HEAD...#{p['head']['sha']}")
      end
    else
      puts "No such number"
    end
  end

  def browse
    num = @args.shift
    if p = pull_num(num)
      Launchy.open(p['html_url'])
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
    pulls.reverse! if option == '--reverse'

    count = 0
    pulls.each do |pull|
      line = []
      line << l(pull['number'], 4)
      line << l(Date.parse(pull['created_at']).strftime("%m/%d"), 5)
      line << l(pull['comments'], 2)
      line << l(pull['title'], 35)
      line << l(pull['head']['label'], 50)
      sha = pull['head']['sha']
      if not_merged?(sha)
        puts line.join ' '
        count += 1
      end
    end
    if count == 0
      puts ' -- no ' + state + ' pull requests --'
    end
  end

  def checkout
    puts "Checking out all open pull requests for #{@user}/#{@repo}"
    pulls = get_open_pull_info
    pulls.each do |pull|
      branch_ref = pull['head']['ref']
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
      next if pull['head']['repository'].nil? # Fork has been deleted
      o = pull['head']['repository']['owner']
      r = pull['head']['repository']['name']
      s = pull['head']['sha']
      if !has_sha(s)
        repo = "#{o}/#{r}"
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

  def has_sha(sha)
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
      config.oauth_token  = github_token if github_token and not github_token.empty?
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
    get_data(PULLS_CACHE_FILE)['closed']
  end

  def get_open_pull_info
    get_data(PULLS_CACHE_FILE)['open']
  end

  def get_data(file)
    data = JSON.parse(File.read(file))
  end

  def cache_pull_info
    response_o = Octokit.pull_requests("#{@user}/#{@repo}")
    response_c = Octokit.pull_requests("#{@user}/#{@repo}", 'closed')
    save_data({'open' => response_o, 'closed' => response_c}, PULLS_CACHE_FILE)
  end

  def save_data(data, file)
    File.open(file, "w+") do |f|
      f.puts data.to_json
    end
  end

  def pull_num(num)
    pull = get_open_pull_info.select { |p| p['number'].to_s == num.to_s }.first
    pull ||= get_closed_pull_info.select { |p| p['number'].to_s == num.to_s }.first
    pull
  end

  def github_insteadof_matching(c, u)
    first = c.collect {|k,v| [v, /url\.(.*github\.com.*)\.insteadof/.match(k)]}.
              find {|v,m| v and u.index(v) and m != nil}

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
