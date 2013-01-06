require 'fileutils'
require 'xcode-yamlizer'
module XcodeYamlizer
  class Cli

    HOOK_PATHS = {
      "pre-commit-hook" =>'.git/hooks/pre-commit',
      "post-merge-hook" =>'.git/hooks/post-merge-hook',
    }
    def answered_yes?(answer)
      answer =~ /y\n/i || answer == "\n"
    end

    def install_all
      HOOK_PATHS.each_key do |key|
        install key
      end
    end
    def install(hook_name)
      if File.exists?(HOOK_PATHS[hook_name])
        ask_to_overwrite hook_name
      end

      install_hook hook_name
    end

    def ask_to_overwrite(hook_name)
      puts "xcode-yamlizer: WARNING There is already a #{hook_name} installed in this git repo."
      print "Would you like to overwrite it? [Yn] "
      answer = $stdin.gets

      if answered_yes?(answer)
        FileUtils.rm(HOOK_PATHS[hook_name])
      else
        puts "Not overwriting existing hook: #{HOOK_PATHS[hook_name]}"
        puts
        exit(1)
      end
    end

    def install_hook (hook_name)
      hook = File.join(XcodeYamlizer.root, 'templates', hook_name)
      FileUtils.cp(hook, HOOK_PATHS[hook_name])
      FileUtils.chmod(0755, HOOK_PATHS[hook_name])
    end

  end
end
