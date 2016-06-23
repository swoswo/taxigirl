# add to default ignore list
ignore %r{^.pre-cvfix}, /lib\//, /bin\//, /.vagrant\//, /vendor\//, /roles-galaxy\//, /bin\//

# enable notifications (osx osx)
notification :terminal_notifier

# check gems with unsolved security issues
# https://github.com/christianhellsten/guard-bundler-audit
guard :bundler_audit, run_on_start: true do
  watch('Gemfile.lock')
end

# check most file types using codevalidator which is a python tool
# but makes fine use of ruby tools (like rubucop which is declared in Gemfile)
# please run `pip install -U -r requirements.txt` to install cv and it's dependencies
guard :shell do
  watch(%r{.(erb|json|md|rst|rb|sh|sql|yaml|yml)|Gemfile|Brewfile|Vagrantfile$}) do |m|
    STDOUT.puts "? validating: #{m[0]}"
    ok = system("command -v codevalidator >/dev/null && codevalidator --verbose #{m[0]}")
    if ok
      n "#{m[0]} is OK", 'Codevalidator', :success
    else
      n "#{m[0]} has issues", 'Codevalidator', :failed
    end
  end
end

# automagically sync the according directory
guard :shell do
  watch(%r{sync\/.*}) do |m|
    STDOUT.puts "= syncing: #{m[0]}"
    ok = system('command -v vagrant >/dev/null && vagrant rsync')
    if ok
      n "#{m[0]} synced OK", 'Vagrant Sync', :success
    else
      n "#{m[0]} did not sync", 'Vagrant Sync', :failed
    end
  end
end

guard :shell do
  watch('requirements.txt') do |m|
    STDOUT.puts "% resolving: #{m[0]}"
    ok = system("make pip-update")
    if ok
      n "#{m[0]} resolved OK", 'pip', :success
    else
      n "#{m[0]} resolved with issues", 'pip', :failed
    end
  end
end
