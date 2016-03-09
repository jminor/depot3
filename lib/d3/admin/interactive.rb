### Copyright 2016 Pixar
###
###    Licensed under the Apache License, Version 2.0 (the "Apache License")
###    with the following modification; you may not use this file except in
###    compliance with the Apache License and the following modification to it:
###    Section 6. Trademarks. is deleted and replaced with:
###
###    6. Trademarks. This License does not grant permission to use the trade
###       names, trademarks, service marks, or product names of the Licensor
###       and its affiliates, except as required to comply with Section 4(c) of
###       the License and to reproduce the content of the NOTICE file.
###
###    You may obtain a copy of the Apache License at
###
###        http://www.apache.org/licenses/LICENSE-2.0
###
###    Unless required by applicable law or agreed to in writing, software
###    distributed under the Apache License with the above modification is
###    distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY
###    KIND, either express or implied. See the Apache License for the specific
###    language governing permissions and limitations under the Apache License.
###
###


module D3
  module Admin

    ### This module contains methods for interacting with the user in the terminal
    ### prompting for data related to administering d3 packages.
    ###
    ### These methods all return a string of user input, possibly an empty string.
    ###
    module Interactive
      require 'readline'
      extend self

      # no spaces at the end of readline completion
      Readline.completion_append_character = ""

      UNSET = "n"

      ### Display a menu of numbered choices, and return the user's choice,
      ### or 'x' if the user is done choosing.
      ###
      ### @param header[String] The text to show above the numbered menu
      ###
      ### @param items[Array<String>] the items of the menu, in order.
      ###
      ### @return [Integer, String] The index of the chosen  chosen, or 'x'
      ###
      def get_menu_choice (header, items)

        # add a 1-based number and ) to the start of each line, like 1),  and 2)...
        items.each_index{|i| items[i]  = "#{i +1}) #{items[i]}"}
        menu_count = items.count
        menu_count_display = "(1-#{menu_count}, x=done, ^c=cancel)"

        menu = "#{header}\n#{items.join("\n")}"

        # clear the screen between displays of the menu, so its always at the top.
        system "clear" or system "cls"
        puts menu
        choice = ""
        while choice == ""
          choice = Readline.readline("Which to change? #{menu_count_display}: ", false)
          break if choice == 'x'

          # they chose a number..
          if choice =~ /^\d+$/
            # map it to one of the editing options
            choice = (choice.to_i) - 1
            # but they might have chosen a higher number than allowws
            choice = "" unless (0..(menu_count - 1)).include? choice
          else
            choice = ""
          end

          # tell them they made a bad choice
          if choice == ""
            puts "\n******* Sorry, invalid choice.\n"
            next
          end
        end # while choice == ""

        return choice
      end # get_menu_choice

      ### Call one of the get_ methods and do the matching validity check,
      ### if desired, repeatedly until a valid value is supplied.
      ###
      ### @param option_or_get_method[Symbol] a key of the OPTIONS hash, or the symbol representing the 'get' method
      ###   to call
      ###
      ### @param default[String] the default value when the user hits return
      ###
      ### @param validate_method[Symbol] the symbol representing the Admin::Validate method
      ###   to use in validating the input. This method must raise an exeption
      ###   if the input is invalid, and return the (possibly modified) value
      ###   when it's valid.
      ###
      ### @return [Object] the validated data from the user
      ###
      def get_value(option_or_get_method, default = nil, validate_method = nil)

        # if the option_or_get_method is one of the keys in OPTIONS, then use OPTIONS[get_method][:get] if it exists
        if D3::Admin::OPTIONS.keys.include?(option_or_get_method)
          option_to_get = option_or_get_method
          get_method = D3::Admin::OPTIONS[option_or_get_method][:get]
          # if we weren't giving a validate method, get it from the OPTIONS
          validate_method ||= D3::Admin::OPTIONS[option_or_get_method][:validate]
        end
        # otherwise we should have been given a symbolic method name.
        get_method ||= option_or_get_method

        valid = :start
        validated = nil
        until valid === true
          puts "\nSorry: #{validated}, Try again.\n" unless valid === :start

          value_input = self.send get_method, default

          # no check method? just return the value
          return value_input if validate_method.nil?

          (valid, validated) = D3::Admin::Validate.validate(value_input, validate_method)

        end #until valid === true
        return validated
      end # get value

      ### Prompt for user input for an option and return the response.
      ###
      ### A Description of the option is displayed, followed by a prompt.
      ### If a default value is provided, the prompt includes the text
      ###  (Hit return for '#{default_value}')
      ###
      ### If the option is defined in D3::Admin::OPTIONS, the data for
      ### the option is used, if not provided in the args.
      ###
      ### If the option is defined as unsettable, a line
      ### "Enter 'n' for none." is also displayed before the prompt and
      ### a value of 'n' will  cause the method to return nil.
      ###
      ### If no prompt is given in the args, the :label is used from
      ### D3::Admin::OPTIONS
      ###
      ### If no default value is given in the args, the one from D3::Admin::OPTIONS
      ### is used. If required is true, the input can't be an empty string.
      ###
      ### Note: watch out for nil vs false in default values
      ###
      ### @param desc[String] A multi-line description of the value to be entered.
      ###
      ### @param prompt[String] The beginning text of the line on which the user enters data
      ###
      ### @param opt[Symbol] The option that is being prompted for, one of the keys of D3::Admin::OPTIONS
      ###
      ### @param default[Object] The default value that will be used if the user just types a return
      ###   (i.e. an empty string is entered). For options that are pkg attributes, this should be in
      ###   the format stored by D3::Package objects e.g. an array of groups, a Boolean, nil.
      ###   The :display_conversion for that option from D3::Admin::OPTIONS will be used to generate the
      ###   diaplay version (e.g. a comma-separated string)
      ###   The symbol :no_default means don't offer a default value.
      ###
      ### @param required[Boolean] re-prompt until a non-empty string is entered.
      ###
      ### @return [String] The data entered by the user, possibly an empty string
      ###
      def prompt_for_data (desc: nil, prompt: nil, opt: nil, default: :no_default, required: true )

        unset_line = nil
        default_display = default

        # look up some info about this option, if needed
        if opt
          opt_def = D3::Admin::OPTIONS[opt]
          if opt_def
            prompt ||= opt_def[:label]
            unset_line = "Enter '#{UNSET}' for none." if opt_def[:unsetable]
            default = opt_def[:default] if opt_def[:default] and default == :no_default
            default_display = opt_def[:display_conversion].call(default) if opt_def[:display_conversion]
          end
        end # if args[:opt]

        # some values are special for displaying
        default_display = case default_display
          when :no_default then  ''
          when D3::Admin::DFT_REQUIRED then '' # the '---Required---' should only be visible in the menu, not the prompt
          when D3::Admin::DFT_NONE then UNSET
          else default_display.to_s
        end

        data_entered = ''
        puts "\n#{desc}" if desc
        puts unset_line if unset_line
        prompt ||= "Please enter a value"
        hit_return = default_display.empty? ? "" : " (Hit return for '#{default_display}')"
        prompt_line = "#{prompt}#{hit_return}: "

        while true do
          data_entered = Readline.readline(prompt_line, false)
          data_entered = default_display if data_entered == ''
          break unless required and data_entered.empty?
        end
        # if 'n' was typed for an unsettable option, return nil
        return nil if opt_def and opt_def[:unsetable] and data_entered == UNSET
        return data_entered.strip
      end # prompt_for_data

      ### Ask the user for an edition or basename
      ### of an existing package.
      ###
      ### @param default[String, nil] the name to offer as default
      ###
      ### @return [String,nil] the edition or basename entered, or nil
      ###
      def get_existing_package(default = nil)
        desc = <<-END_DESC
EXISTING PACKAGE
Enter a package edition or basename for an existing d3 package.
If a basename, the currently live package for that basename will be used.
Enter:
   - 'v' to view a list of all packages with the basenames and editions in d3.
        END_DESC

        input = "v"
        while input == "v" do
          input = prompt_for_data(desc: desc, prompt: "Edition or Basename", default: default, required: true)
          D3::Admin::Report.show_all_basenames_and_editions if input == "v"
        end
        return input
      end # get existing pkg

      ### Ask the user for an id or name
      ### of an existing JSS package to import into d3
      ###
      ### @return [String] the name or id entered, or nil
      ###
      def get_jss_package_for_import (default = nil)
        desc = <<-END_DESC
IMPORT JSS PACKAGE
Enter a package id or display-name for
an existing JSS package to import into d3.
Enter:
   - 'v' to view a list of all JSS package names not in d3.
        END_DESC

        input = "v"
        while input == "v" do
          input = prompt_for_data(desc: desc, prompt: "JSS id or display name", default: default, required: true)
          D3::Admin::Report.show_pkgs_available_for_import if input == "v"
        end
        return input
      end # get existing pkg

      ### get a basename from the user
      def get_basename (default = nil)
        desc = <<-END_DESC
BASENAME
Enter a d3 basename for this package.
Enter 'v' to view a list of all basenames in d3 and
the newest edition for each.
        END_DESC

        input = "v"
        while input == "v" do
          input = prompt_for_data(desc: desc, prompt: "Basename", required: true)
          D3::Admin::Report.show_all_basenames_and_editions if input == "v"
        end
        return input
      end # get basename

      ### get a package name from user
      def get_package_name (default = nil)
        desc = <<-END_DESC
JSS PACKAGE NAME
Enter a unique name for this package in d3 and Casper.
Enter 'v' to view a list of package names currently in d3.
        END_DESC
        input = "v"
        while input == "v" do
          input = prompt_for_data(opt: :package_name, desc: desc, default: default, required: true)
          D3::Admin::Report.show_existing_package_ids if input == "v"
        end
        return input
      end # get pkg name

       ### get a package name from user
      def get_filename (default = nil)
        desc = <<-END_DESC
INSTALLER FILENAME
Enter a unique name for this package's installer file
on the master distribution point. The file will be
renamed to this name on the distribution point.
Enter 'v' to see a list of existing pkg filenames in the JSS
        END_DESC
        input = "v"
        while input == "v" do
          input = prompt_for_data(opt: :filename, desc: desc, default: default, required: true)
          D3::Admin::Report.show_existing_package_ids if input == "v"
        end
        return input
      end # get pkg name

      ### Get a version from the user
      ###
      ### @param default[String] the value to use when the user types a return.
      ###
      ### @return [String] the value to use as the version
      def get_version (default = nil)
        desc = <<-END_DESC
VERSION
Enter a version for this package.
All spaces will be converted to underscores.
        END_DESC

        prompt_for_data(opt: :version, desc: desc, default: default, required: true)
      end

      ### Get a revision from the user
      ###
      ### @param default[String] the rev to use when the user types a return.
      ###
      ### @return [String] the value to use as the rev
      ###
      def get_revision (default = nil)
        desc = <<-END_DESC
REVISION
Enter a Package revision for this package.
This is an integer representing a new packaging of
an existing version of a given basename.
        END_DESC

        prompt_for_data(opt: :revision, desc: desc, default: default, required: true)
      end

      ### Get a multiline description from the user using the editor
      ### of their choice: nano, vi, emacs, or ENV['EDITOR']
      ###
      ### @param desc[String] the description to start with
      ###
      ### @return [String] the desired description
      ###
      def get_description(current_desc = "")

        # do we have a current desc to display and possibly keep?
        current_desc_review = ""
        unless current_desc.to_s.empty?
          current_desc_review = "\n----- Current Description -----\n#{current_desc}\n-------------------------------\n\n"
        end

        # the blurb to show the user
        input_desc = <<-END_DESC
DESCRIPTION
Create a multi-line description of this package:
   - what does the installed thing do?
   - where did it come from, where to get updates?
   - who maintains it in your environment?
   - any other info useful to d3 and Casper admins.
  (don't just say "installs foo" when "foo" is the basename)
  #{current_desc_review}Enter:
   - 'n' to edit it using 'nano'
   - 'v' to edit it using 'vi' or 'vim'
   - 'e' to edit it using 'emacs'
   - 'b' to have a blank description
Anything else will edit with the EDITOR for your environment
or 'nano' if none is set.
        END_DESC

        # show it, get response
        puts input_desc
        choice = Readline.readline("Your choice (hit return to keep it as-is): ", false)

        # keep or empty?
        return current_desc if choice.empty?

        return "" if choice.casecmp('b') == 0

        # make a tem file, save current into it
        desc_tmp_file = Pathname.new Tempfile.new("d3_description_")
        desc_tmp_file.jss_save current_desc

        # which editor?
        if choice.casecmp('v') == 0
          cmd = "/usr/bin/vim"
        elsif choice.casecmp('e') == 0
          cmd = "/usr/bin/emacs"
        elsif choice.casecmp('n') == 0
          cmd = "/usr/bin/nano -L"
        else
          cmd = ENV['EDITOR']
          cmd ||= "/usr/bin/nano -L"
        end

        system "#{cmd} '#{desc_tmp_file}'"

        result = desc_tmp_file.read.chomp
        desc_tmp_file.delete
        return result.chomp
      end # get_description

      ### Get the local path to the package being added to d3
      ### Also sets @build_installer, and @build_installer_type
      ### if the source is a root-folder rather than a .pkg or .dmg
      ###
      ### @return [Pathname] the local path to the pkg source
      def get_source_path (default = false)
        desc = <<-END_DESC
SOURCE
Enter the path to a .pkg or .dmg installer
or a 'root' folder from which to build one.
END_DESC

        # dragging in items from the finder will esacpe spaces in the path with \'s
        # in the shell this is good, but ruby is interpreting the \'s, so lets remove them.
        prompt_for_data(opt: :source_path, desc: desc, default: default, required: true).strip.gsub(/\\ /," ")
      end

      ### If we're builting a pkg, should we build a .pkg, or a .dmg?
      ###
      ### @return [Symbol] :pkg or :dmg
      ###
      def get_package_build_type(default = D3::Admin::DFT_PKG_TYPE)
        desc = <<-END_DESC
PACKAGE BUILD TYPE
Looks like we need to build the installer from a package-root.
Should we build a .pkg or .dmg?  ( p = pkg, d = dmg )
        END_DESC
        prompt_for_data(opt: :package_build_type, desc: desc, default: default, required: true)
      end

      ### Get the pkg identifier for building .pkgs
      ###
      ### @param default[String] the default value when hitting return
      ###
      ### @return [String] the prefix to use
      ###
      def get_pkg_identifier (default = nil)
              desc = <<-END_DESC
PKG IDENTIFIER
Enter the Apple .pkg indentifier for building a .pkg.
E.g. com.mycompany.myapp
        END_DESC
        prompt_for_data(opt: :pkg_identifier_prefix, desc: desc, default: default, required: true)
      end

      ### Get the pkg identifier prefex for building .pkgs
      ### When building .pkgs, this string is prefixed to the
      ### basename to create the Apple Pkg identifier.
      ### For example if the value is com.pixar.d3, then
      ### when building a pkg with the basename "foo"
      ### the identifier will be com.pixar.d3.foo
      ###
      ### This value is saved in the admin prefs for future use.
      ###
      ### @param default[String] the default value when hitting return
      ###
      ### @return [String] the prefix to use
      ###
      def get_pkg_identifier_prefix (default = D3::Admin::DFT_PKG_ID_PREFIX)
              desc = <<-END_DESC
PKG IDENTIFIER PREFIX
Enter the prefix to prepend to a basename to create an Apple .pkg indentifier.
E.g. If you enter 'com.mycompany', then when you build a .pkg with basename 'foo'
the default .pkg identifier  will be 'com.mycompany.foo'
        END_DESC
        prompt_for_data(opt: :pkg_identifier_prefix, desc: desc, default: default, required: true)
      end

      ### Get the desired local workspace for building pkgs
      ### Defaults to ENV['HOME']
      ###
      ### @param default[Pathname, String] the default choice when typing return
      ###
      ### @return [Pathname] the path to the workspace
      ###
      def get_workspace (default = ENV['HOME'])
        desc = <<-END_DESC
PACKAGE BUILD WORKSPACE
Enter the path to a folder where we can build packages.
This will be stored between uses of d3admin.
        END_DESC
        Pathname.new prompt_for_data(opt: :workspace, desc: desc, default: default, required: true)
      end

      ### Ask if the pkg should preserve
      ### source ownership, or apply OS defaults
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the users response
      ###
      def get_pkg_preserve_owners (default = 'n')
        desc = <<-END_DESC
PRESERVE SOURCE OWNERSHIP
When building a .pkg, the OS generally sets the ownership and permissions
of the payload to match OS standards, e.g. Apps owned by 'root' with group
'admin' or 'wheel'

If desired you can preserve the current ownership and permissions of the source
folder contents when the payload is installed. This is generally not recomended.

Should we override the OS and preserve the ownership on
the source folder when the item is installed on the client?
Enter 'y' or 'n'
        END_DESC
        prompt_for_data(desc: desc, prompt: "Preserve ownership (y/n)", default: default, required: true)
      end

      ### Get a pre-install script, either local file, JSS id, or JSS name
      ###
      ### @param default[String] the name of an existing JSS script to use
      ###
      ### @return [Pathname, Integer, nil] The local script file, or the JSS id of the
      ###   chosen script
      ###
      def get_pre_install_script (default = nil)
        get_script "PRE-INSTALL SCRIPT", :pre_install , default
      end

      ### Get a post-install script, either local file, JSS id, or JSS name
      ###
      ### @param default[String] the name of an existing JSS script to use
      ###
      ### @return [Pathname, Integer, nil] The local script file, or the JSS id of the
      ###   chosen script
      ###
      def get_post_install_script (default = nil)
        get_script "POST-INSTALL SCRIPT", :post_install , default
      end

      ### Get a pre-remove script, either local file, JSS id, or JSS name
      ###
      ### @param default[String] the name of an existing JSS script to use
      ###
      ### @return [Pathname, Integer, nil] The local script file, or the JSS id of the
      ###   chosen script
      ###
      def get_pre_remove_script (default = nil)
         get_script "PRE-REMOVE SCRIPT", :pre_remove , default
      end

      ### Get a post-remove script, either local file, JSS id, or JSS name
      ###
      ### @param default[String] the name of an existing JSS script to use
      ###
      ### @return [Pathname, Integer, nil] The local script file, or the JSS id of the
      ###   chosen script
      ###
      def get_post_remove_script (default = nil)
        get_script "POST-REMOVE SCRIPT", :post_remove , default
      end

      ### Get a script, either local file, JSS id, or JSS name
      ###
      ### @param default[String] the name of an existing JSS script to use
      ###
      ### @return [Pathname, Integer, nil] The local script file, or the JSS id of the
      ###   chosen script
      ###
      def get_script (heading, opt , default = nil)
        desc = <<-END_DESC
#{heading}
Enter a path to a local file containing the script
or the name or id of an existing script in the JSS.
Enter 'v' to view a list of scripts in the JSS.
        END_DESC

        result = "v"
        while result == "v" do
          result = prompt_for_data(opt: opt, desc: desc, default: default, required: true)
          D3.less_text JSS::Script.all_names.sort_by{|s| s.downcase}.join("\n") if result == "v"
        end
        return result
      end

      ### Prompt the admin for one or more auto-groups for this installer
      ###
      ### @param default[nil,String,Array<String>] The groups to use
      ###
      ### @return [String]
      def get_auto_groups (default = nil)
        desc = <<-END_DESC
AUTO-INSTALL GROUPS
Enter a comma-separated list of JSS Computer Group names whose members should
have this package installed automatically when it is made live.
Enter 'v' to view a list of computer groups.
Enter '#{D3::STANDARD_AUTO_GROUP}' to install on all machines.
        END_DESC
        get_groups desc, :auto_groups, default
      end # get auto

      ### Prompt the admin for one or more auto-groups for this installer
      ###
      ### @param default[nil,String,Array<String>] The groups to
      def get_excluded_groups (default = nil)

        desc = <<-END_PROMPT
EXCLUDED GROUPS
Enter a comma-separated list of JSS Computer Group names
whose members should not get this installed without force.
Enter 'v' to view list of computer groups.
        END_PROMPT
        get_groups desc, :excluded_groups, default
      end # get auto

      ### Prompt the admin for one or more groups for showing scoped group lists
      ###
      ### @param type[String] auto or excluded - the kind of scoping for the group
      ###
      def get_scoped_groups (type)
        scoped = type == :auto ? 'auto-installed' : 'excluded'
        desc = <<-END_PROMPT
COMPUTER GROUPS
Enter a comma-separated list of JSS Computer Group names
to use for showing the #{scoped} packages.
Enter 'v' to view list of computer groups.
        END_PROMPT
        get_groups desc, :scoped_groups, :no_default
      end # get auto

      ### Prompt the admin for one or more groups
      ###
      ### @param default[String,Array<String>] The groups to use
      ###
      ### @return [String,nil]
      ###
      def get_groups (desc, opt, default = nil)

        result = "v"
        while result == "v" do
          result = prompt_for_data(opt: opt, desc: desc,  default: default, required: true)
          D3.less_text JSS::ComputerGroup.all_names.sort_by{|s| s.downcase}.join("\n") if result == "v"
        end

        return result
      end # get auto

      ### Get a list of allowed OSes for this pkg
      ###
      ### @param default[String, Array] An array or comma-separated list of OSes
      ###  selected when the user hits return
      ###
      ### @return [String,nil] A comma-separated list of allowed OSes
      ###
      def get_oses (default = [])
        desc = <<-END_DESC
LIMIT TO OS's
Enter a comma-separated list of OS's allowed to
install this package, e.g. '10.8.5, 10.9.5, 10.10.x'
Use '>=' to set a minimum OS, e.g. '>=10.8.5'
        END_DESC
        prompt_for_data(desc: desc, opt: :oses, default: default, required: true)
      end

      ### Get a the CPU-type limitation for this package
      ###
      ### @param default[String] the default limitation if the user hits return
      ###
      ### @return [Symbol,nil] :ppc, :intel, or nil
      ###
      def get_cpu_type (default = 'x86')
        desc = <<-END_DESC
LIMIT TO CPU TYPE
Should this packge be limited to certain CPU types?
Enter 'ppc' or 'x86'  or 'none' for neither.
        END_DESC
        prompt_for_data(desc: desc, opt: :cpu_type, default: default, required: true)
      end

      ### Get a JSS Category from the user
      ###
      ### @param default[String] the category used when the user hits return
      ###
      ### @return [String] the category entered by the user
      ###
      def get_category (default = "n")
        desc = <<-END_DESC
CATEGORY
Enter the JSS category name for this package.
Enter:
   - 'v' to view all JSS categories
   - 'n' for no category
        END_DESC

        result = "v"
        while result == "v" do
          result = prompt_for_data(desc: desc, prompt: "Category", default: default, required: true)
          D3.less_text JSS::Category.all_names.sort_by{|c| c.downcase}.join("\n") if result == "v"
        end
        return nil if result == 'n'
        result
      end

      ### Get a pattern to match for the prohibiting process
      ### If this matches a line of output from `/bin/ps -A -c -o comm`
      ### at install time, then the install won't happen.
      ### Strings must match a whole line, Regexps will work with
      ### any match.
      ###
      ### @param default[String,Regexp] the default pattern when hitting return
      ###
      ### @return [Regexp,nil] the pattern to match
      ###
      def get_prohibiting_process (default = 'n')
        desc = <<-END_DESC
PROHIBITING PROCESS
Enter the name of a process as it appears on one line
of the output of `/bin/ps -A -c -o comm`

If this process is running at install time,
the installation will be skipped.
Matching is case-insensitive

Enter 'n' for none.
        END_DESC

        result = prompt_for_data(desc: desc, prompt: "Prohibiting Process", default: default, required: true)
        return nil if result == 'n'
        result
      end

      ### Ask if this package is uninstallable
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the users response
      ###
      def get_removable (default = 'y')
        desc = <<-END_DESC
REMOVABLE
Can this package be uninstalled?
Enter 'y' or 'n'
        END_DESC
        prompt_for_data(desc: desc, prompt: "Removable? (y/n)", default: default, required: true)
      end

      ### Ask if we should ininstall older versions of this basename
      ### before installing this one
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the users response
      ###
      def get_remove_first (default = 'y')
        desc = <<-END_DESC
UNINSTALL OLDER VERSIONS
Should older versions of this basename be uninstalled
(if they are removable) before attempting to install this package?
Enter 'y' or 'n'
        END_DESC
        prompt_for_data(desc: desc, prompt: "Remove older installs first? (y/n)", default: default, required: true)
      end

      ### Ask if this package needs a reboot
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the users response
      ###
      def get_reboot (default = 'n')
        desc = <<-END_DESC
REBOOT REQUIRED (PUPPIES!)
Does this package require a reboot after installation?
If so, it will be added to the Puppy Queue when installed
with 'd3 install', and the user will be notified to log
out as soon as possible.
Enter 'y' or 'n'
        END_DESC
        prompt_for_data(desc: desc, prompt: "Requires reboot? (y/n)", default: default, required: true)

      end

      ### Get an expiration period (# of days) from the user
      ###
      ### @param default[Integer] the # to use when the user types a return.
      ###
      ### @return [Integer] the value to use as the expiration
      ###
      def get_expiration (default = 0)
        desc = <<-END_DESC
EXPIRATION
On machines that allow package expiration,
should this package be removed after some
number of days without being used?
Enter the number of days, or 0 for no expiration.
        END_DESC

        prompt_for_data(desc: desc, prompt: "Expiration days", default: default, required: true)
      end

      ### Get the path to the application to monitor for expiration
      ###
      ### @param default[Pathname, String] the default choice when typing return
      ###
      ### @return [Pathname] the path to the application
      ###
      def get_expiration_path (default = 'n')
        desc = <<-END_DESC
EXPIRATION PATH
Enter the path to a the application that must be used
to prevent expiration.
E.g. /Applications/Google Chrome.app
Enter 'n' for none
        END_DESC
        prompt_for_data(desc: desc, prompt: "Expiration Path", default: default, required: true)
      end

      ### when deleting a pkg, should its pre- and post- scripts be deleted
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the users response
      ###
      def get_delete_scripts (default = 'n')
        desc = <<-END_DESC
DELETE ASSOCIATED SCRIPTS?
When deleting a package, should any associated scripts
(pre-install, post-install, pre-remove, post-remove) also be deleted?

NOTE: If any other d3 packages or policies are using the scripts
they won't be deleted, but the other users will be reported.
Enter 'y' or 'n'
        END_DESC
        prompt_for_data(desc: desc, prompt: "Delete Scripts? (y/n)", default: default, required: true)
      end

      ### when deleting a pkg, should it be kept in the JSS?
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the users response
      ###
      def get_keep_in_jss (default = 'n')
        desc = <<-END_DESC
KEEP THE PACKAGE IN THE JSS?
When deleting a package, should it be kept as a JSS package
and only deleted from d3?
Enter 'y' or 'n'
        END_DESC
        prompt_for_data(desc: desc, prompt: "Keep in JSS? (y/n)", default: default, required: true)
      end

      ### what kind of package list are we showing?
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the chosen report type
      ###
      def get_show_type (default = D3::Admin::Report::DFT_SHOW_TYPE)
        desc = <<-END_DESC
SERVER PACKAGE LIST
Enter the type of list you'd like to generate about packages in d3.

One of:
  all        - all packages in d3
  pilot      -  packages newer than live
  live       - live packages
  deprecated - old packages that used to be live
  skipped    - old packages that were never made live
  missing    - packages in d3, but not Casper
  auto       - packages auto-installed for a given computer group
  excluded   - packages not available to a given computer group
END_DESC
        prompt_for_data(desc: desc, prompt: "Show packages", default: default, required: true)
      end

      ### what kind of client report are we generating?
      ###
      ### @param default[String] the default answer when user hits return
      ###
      ### @return [String] the chosen report type
      ###
      def get_report_type (default = D3::Admin::Report::DFT_REPORT_TYPE)
        desc = <<-END_DESC
CLIENT COMPUTER REPORT TYPE
Enter the type of report you'd like to generate about
d3 client computers.
One of:
  installed  - computers with any edition of the target basename
  pilot      - computers piloting the target basename
  deprecated - computers with old editions of the target basename
  frozen     - computers where the target basename is frozen
  puppies    - computers where the target is in the puppy (logout) queue
  receipts   - all d3 packages installed on target computer
END_DESC
        prompt_for_data(desc: desc, prompt: "Report type", default: default, required: true)
      end

      ### What computer are we generating a receipt report for?
      ###
      ### @return [String] A computer name in the JSS
      ###
      def get_computer
                desc = <<-END_DESC
JSS COMPUTER NAME
Enter the name of a computer Casper.
Enter 'v' to view a list available computer names.
END_DESC
        input = "v"
        while input == "v" do
          input = prompt_for_data(desc: desc, prompt: "Computer name", default: nil, required: true)
          D3::Admin::Report.show_available_computers_for_reports if input == "v"
        end
        return input
      end # get computer

      ### Get the config target
      ###
      ### @param default[String] the default value when hitting return
      ###
      ### @return [String] the prefix to use
      ###
      def get_config_target (default = "all")
              desc = <<-END_DESC
CONFIGURATION
Which setting would you like to configure?
  jss - the JSS and credentials (stored in your keychain)
  db  - the MySQL server and credentials (stored in your keychain)
  dist - the master distribution point RW password (stored in your keychain)
  workspace - the folder in which to build .pkgs and .dmgs
  pkg-id-prefix - the prefix for the .pkg identifier when building .pkgs
  all - all of the above

        END_DESC
        prompt_for_data(opt: :pkg_identifier_prefix, desc: desc, default: default, required: true)
      end


    end # module
  end # module Admin
end # module D3
