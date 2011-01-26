require 'rubygems'
require 'json'
require 'httparty'
require 'pp'

class GitPulls

  PULLS_CACHE_FILE = '.git/pulls_cache.json'

  def initialize(args)
    @command = args.shift
    @user, @repo = repo_info
    @args = args
  end

  def self.start(args)
    GitPulls.new(args).run
  end

  def run
    if @command && self.respond_to?(@command)
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
    puts "Try: update, list, show, merge, browse"
    puts "or call with '--help' for usage information"
  end

  def usage
    puts <<-USAGE
Usage: git pulls update
   or: git pulls list [--reverse]
   or: git pulls show <number> [--full]
   or: git pulls browse <number>
   or: git pulls merge <number>
    USAGE
  end

  def merge
    num = @args.shift
    option = @args.shift
    if p = pull_num(num)
      o = p['head']['repository']['owner']
      r = p['head']['repository']['name']
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
    option = @args.shift
    if p = pull_num(num)
      puts "Number   : #{p['number']}"
      puts "Label    : #{p['head']['label']}"
      puts "Created  : #{p['created_at']}"
      puts "Votes    : #{p['votes']}"
      puts "Comments : #{p['comments']}"
      puts
      puts "Title    : #{p['title']}"
      puts "Body     :"
      puts
      puts p['body']
      puts
      puts '------------'
      puts
      if option == '--full'
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
      `open #{p['html_url']}`
    else
      puts "No such number"
    end
  end

  def list
    option = @args.shift
    puts "Open Pull Requests for #{@user}/#{@repo}" 
    pulls = get_pull_info
    pulls.reverse! if option == '--reverse'
    pulls.each do |pull|
      line = []
      line << l(pull['number'], 4)
      line << l(Date.parse(pull['created_at']).strftime("%m/%d"), 5)
      line << l(pull['comments'], 2)
      line << l(pull['title'], 35)
      line << l(pull['head']['label'], 20)
      sha = pull['head']['sha']
      if not_merged?(sha)
        puts line.join ' '
      end
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
    pulls = get_pull_info
    repos = {}
    pulls.each do |pull|
      o = pull['head']['repository']['owner']
      r = pull['head']['repository']['name']
      s = pull['head']['sha']
      if !has_sha(s)
        repo = "#{o}/#{r}"
        repos[repo] = true
      end
    end
    repos.each do |repo, bool|
      puts "  fetching #{repo}"
      git("fetch git://github.com/#{repo}.git refs/heads/*:refs/pr/#{repo}/*")
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

  # API/DATA HELPER FUNCTIONS #
 
  def get_pull_info
    get_data(PULLS_CACHE_FILE)['pulls']
  end

  def cache_pull_info
    path = "/pulls/#{@user}/#{@repo}/open"
    response = HTTParty.get('https://github.com/api/v2/json' << path)
    save_data(response, PULLS_CACHE_FILE)
  end

  def get_data(file)
    data = JSON.parse(File.read(file))
  end

  def save_data(data, file)
    File.open(file, "w+") do |f|
      f.puts data.to_json
    end
  end

  def pull_num(num)
    data = get_pull_info
    data.select { |p| p['number'].to_s == num.to_s }.first
  end


  def repo_info
    c = {}
    config = git('config --list')
    config.split("\n").each do |line| 
      k, v = line.split('=')
      c[k] = v
    end
    u = c['remote.origin.url']
    if m = /github\.com.(.*?)\/(.*?)\.git/.match(u)
      user = m[1]
      proj = m[2]
    end
    [user, proj]
  end

  def git(command)
    `git #{command}`.chomp
  end
end
