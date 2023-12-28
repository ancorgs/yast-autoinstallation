# File:  clients/autoinst_scripts.ycp
# Package:  Autoinstallation Configuration System
# Summary:  Scripts
# Authors:  Anas Nashif<nashif@suse.de>
#
# $Id$
module Yast
  module AutoinstallScriptDialogsInclude
    def initialize_autoinstall_script_dialogs(_include_target)
      textdomain "autoinst"

      Yast.import "Popup"
      Yast.import "AutoinstConfig"
    end

    # Script Configuration
    # @return  script configuration dialog
    def script_dialog_contents
      allscripts = AutoinstScripts.scripts.map do |s|
        Item(
          Id(s.filename),
          s.filename,
          AutoinstScripts.typeString(s.class.type),
          # init scripts does not have interpreter. Is it correct?
          s.respond_to?(:interpreter) ? s.interpreter : ""
        )
      end
      contents = VBox(
        Left(Label(_("Available Scripts"))),
        Table(
          Id(:table),
          Opt(:notify),
          Header(_("Script Name"), _("Type"), _("Interpreter")),
          allscripts
        ),
        HBox(
          PushButton(Id(:new), Label.NewButton),
          PushButton(Id(:edit), Label.EditButton),
          PushButton(Id(:delete), Label.DeleteButton)
        )
      )
      deep_copy(contents)
    end

    # Dialog for adding/Editing  a script
    # @param [Symbol] mode `edit or `new
    # @param [String] name script name
    # @return [Symbol]

    def ScriptDialog(mode, name)
      script = {}
      if mode == :edit
        script_o = AutoinstScripts.scripts.find { |s| s.filename == name }
        if script_o
          script = script_o.to_hash
          script["type"] = script_o.class.type
        end
      end

      # help 1/6
      help = _(
        "\n" \
        "<h3>Preinstallation Scripts</h3>\n" \
        "<P>Add commands to run on the system  before the installation begins. </P>\n"
      )
      # help 2/6
      help = Ops.add(
        help,
        _(
          "\n" \
          "<h3>Postinstallation Scripts</h3>\n" \
          "<P>You can also add commands to execute on the system after the installation\n" \
          "is completed. These scripts are run outside the chroot environment.\n" \
          "</P>"
        )
      )
      # help 3/6
      help = Ops.add(
        help,
        _(
          "\n" \
          "<H3>Chroot Scripts</H3>\n" \
          "<P>For your postinstallation script to run inside the chroot\n" \
          "environment, choose the <i>chroot scripts</i> options. Those scripts are\n" \
          "run before the system reboots for the first time. By default, the chroot \n" \
          "scripts are run in the installation system. To access files in the installed \n" \
          "system, always use the mount point \"/mnt\" in your scripts.\n" \
          "</P>\n"
        )
      )
      # help 4/6
      help = Ops.add(
        help,
        _(
          "\n" \
          "<p>It is possible to run chroot scripts in a later stage after\n" \
          "the boot loader has been configured using the special boolean tag \"chrooted\".\n" \
          "This runs the scripts in the installed system. \n" \
          "</p>\n"
        )
      )
      # help 5/6
      help = Ops.add(
        help,
        _(
          "\n" \
          "<H3>Init Scripts</H3>\n" \
          "<P>These scripts are executed during the initial boot process and after\n" \
          "YaST has finished configuring the system. The final scripts are executed \n" \
          "using a special <b>rc</b> script that is executed only once. \n" \
          "The final scripts are executed toward the end of the boot\n" \
          "process and after network has been initialized.\n" \
          "</P>\n"
        )
      )

      # help 6/6
      help = Ops.add(
        help,
        _(
          "\n" \
          "<H3>Interpreter:</H3>\n" \
          "<P>Preinstallation scripts can only be shell scripts. Do not use <i>Perl</i> or \n" \
          "<i>Python</i> for preinstallation scripts.\n" \
          "</P>\n"
        )
      )
      help = Ops.add(
        help,
        _(
          "\n" \
          "<H3>Feedback and Debug:</H3>\n" \
          "<P>All scripts except the init scripts can show STDOUT+STDERR " \
          "in a pop-up box as feedback.\n" \
          "If you turn on debugging, you get more output in the " \
          "feedback dialog that might help\n" \
          "you to debug your script.</P>\n"
        )
      )

      title = _("Script Editor")

      contents = VBox(
        HBox(
          TextEntry(
            Id(:filename),
            _("&File Name"),
            Ops.get_string(script, "filename", "")
          ),
          ComboBox(
            Id(:interpreter),
            Opt(:editable),
            _("&Interpreter"),
            [
              Item(
                Id("perl"),
                _("Perl"),
                Ops.get_string(script, "interpreter", "shell") == "perl"
              ),
              Item(
                Id("shell"),
                _("Shell"),
                Ops.get_string(script, "interpreter", "shell") == "shell"
              ),
              Item(
                Id("shell"),
                _("Python"),
                Ops.get_string(script, "interpreter", "shell") == "python"
              )
            ]
          ),
          ComboBox(
            Id(:type),
            Opt(:notify),
            _("&Type"),
            [
              Item(
                Id("pre-scripts"),
                # TRANSLATORS: Pre installation script type
                _("Pre"),
                Ops.get_string(script, "type", "") == "pre-scripts"
              ),
              Item(
                # TRANSLATORS: Post partitioning installation script type
                Id("postpartitioning-scripts"),
                _("PostPartitioning"),
                Ops.get_string(script, "type", "") == "post-scripts"
              ),
              Item(
                Id("chroot-scripts"),
                # TRANSLATORS: Change root installation script type
                _("Chroot"),
                Ops.get_string(script, "type", "") == "chroot-scripts"
              ),
              Item(
                Id("post-scripts"),
                # TRANSLATORS: Post installation script type
                _("Post"),
                Ops.get_string(script, "type", "") == "post-scripts"
              ),
              Item(
                Id("init-scripts"),
                # TRANSLATORS: Init system post installation script type
                _("Init"),
                Ops.get_string(script, "type", "") == "init-scripts"
              )
            ]
          ),
          HStretch(),
          Empty()
        ),
        HBox(
          # a checkbox where you can choose if you want to see script-feedback output or not
          CheckBox(
            Id(:feedback),
            Opt(:notify),
            _("&Feedback"),
            Ops.get_boolean(script, "feedback", false)
          ),
          # a checkbox where you can choose if you want to see script-debug output or not
          CheckBox(
            Id(:debug),
            _("&Debug"),
            Ops.get_boolean(script, "debug", true)
          ),
          CheckBox(
            Id(:chrooted),
            _("&Chrooted"),
            Ops.get_boolean(script, "chrooted", false)
          )
        ),
        HBox(
          # a checkbox where you can choose if you want to see script-feedback output or not
          ComboBox(
            Id(:feedback_type),
            _("&Feedback Type"),
            [
              Item(
                Id(""),
                _("none"),
                Ops.get_string(script, "feedback_type", "") == ""
              ),
              Item(
                Id("message"),
                _("Message"),
                Ops.get_string(script, "feedback_type", "") == "message"
              ),
              Item(
                Id("warning"),
                _("Warning"),
                Ops.get_string(script, "feedback_type", "") == "warning"
              ),
              Item(
                Id("error"),
                _("Error"),
                Ops.get_string(script, "feedback_type", "") == "error"
              )
            ]
          )
        ),
        VSpacing(1),
        HBox(
          TextEntry(
            Id(:notification),
            Opt(:notify),
            _("Text of the notification popup"),
            Ops.get_string(script, "notification", "")
          )
        ),
        HBox(
          TextEntry(
            Id(:location),
            Opt(:notify),
            _("Script Location"),
            Ops.get_string(script, "location", "")
          )
        ),
        HBox(
          MultiLineEdit(
            Id(:source),
            Opt(:notify),
            _("S&cript Source"),
            Ops.get_string(script, "source", "")
          )
        ),
        VSpacing(1),
        HBox(
          PushButton(Id(:save), Label.SaveButton),
          PushButton(Id(:loadsource), _("&Load new source")),
          PushButton(Id(:cancel), Label.CancelButton)
        )
      )

      Wizard.HideNextButton
      Wizard.HideBackButton
      Wizard.HideAbortButton
      Wizard.SetContents(title, contents, help, true, true)
      type = Convert.to_string(UI.QueryWidget(Id(:type), :Value))
      case type
      when "pre-scripts", "post-scripts"
        UI.ChangeWidget(Id(:chrooted), :Enabled, false)
      when "init-scripts"
        UI.ChangeWidget(Id(:chrooted), :Enabled, false)
        UI.ChangeWidget(Id(:feedback), :Enabled, false)
        UI.ChangeWidget(Id(:notification), :Enabled, false)
      end

      if Ops.greater_than(
        Builtins.size(
          Convert.to_string(UI.QueryWidget(Id(:location), :Value))
        ),
        0
      )
        UI.ChangeWidget(Id(:source), :Enabled, false)
      else
        UI.ChangeWidget(Id(:source), :Enabled, true)
        if Ops.greater_than(
          Builtins.size(
            Convert.to_string(UI.QueryWidget(Id(:source), :Value))
          ),
          0
        )
          UI.ChangeWidget(Id(:location), :Enabled, false)
        end
      end

      if !Convert.to_boolean(UI.QueryWidget(Id(:feedback), :Value))
        UI.ChangeWidget(Id(:feedback_type), :Enabled, false)
      end

      UI.ChangeWidget(Id(:filename), :Enabled, false) if mode == :edit

      ret = :none
      loop do
        ret = Convert.to_symbol(UI.UserInput)
        case ret
        when :save
          scriptName = Convert.to_string(UI.QueryWidget(Id(:filename), :Value))

          type2 = Convert.to_string(UI.QueryWidget(Id(:type), :Value))
          interpreter = Convert.to_string(
            UI.QueryWidget(Id(:interpreter), :Value)
          )
          source = Convert.to_string(UI.QueryWidget(Id(:source), :Value))
          feedback = Convert.to_boolean(UI.QueryWidget(Id(:feedback), :Value))
          feedback_type = Convert.to_string(
            UI.QueryWidget(Id(:feedback_type), :Value)
          )
          debug = Convert.to_boolean(UI.QueryWidget(Id(:debug), :Value))
          chrooted = Convert.to_boolean(UI.QueryWidget(Id(:chrooted), :Value))
          location = Convert.to_string(UI.QueryWidget(Id(:location), :Value))
          notification = Convert.to_string(
            UI.QueryWidget(Id(:notification), :Value)
          )

          if (source == "" && location == "") || scriptName == ""
            Popup.Message(
              _(
                "Provide at least the script\nname and the location or content of the script.\n"
              )
            )
            ret = :again
            next
          else
            AutoinstScripts.AddEditScript(
              scriptName,
              source,
              interpreter,
              type2,
              chrooted,
              debug,
              feedback,
              feedback_type,
              location,
              notification
            )
          end
        when :loadsource
          filename = UI.AskForExistingFile(
            AutoinstConfig.Repository,
            "*",
            _("Select a file to load.")
          )
          if filename != ""
            source = Convert.to_string(
              SCR.Read(path(".target.string"), filename)
            )
            UI.ChangeWidget(Id(:source), :Value, source)
            next
          end
        when :type
          type2 = Convert.to_string(UI.QueryWidget(Id(:type), :Value))
          case type2
          when "init-scripts"
            UI.ChangeWidget(Id(:feedback), :Enabled, false)
            UI.ChangeWidget(Id(:chrooted), :Enabled, false)
            UI.ChangeWidget(Id(:feedback), :Value, false)
            UI.ChangeWidget(Id(:chrooted), :Value, false)
            UI.ChangeWidget(Id(:notification), :Enabled, false)
          when "chroot-scripts"
            UI.ChangeWidget(Id(:chrooted), :Enabled, true)
            UI.ChangeWidget(Id(:feedback), :Enabled, true)
            UI.ChangeWidget(Id(:notification), :Enabled, true)
          when "post-scripts", "pre-scripts"
            UI.ChangeWidget(Id(:chrooted), :Enabled, false)
            UI.ChangeWidget(Id(:chrooted), :Value, false)
            UI.ChangeWidget(Id(:feedback), :Enabled, true)
            UI.ChangeWidget(Id(:notification), :Enabled, true)
          end
        when :feedback
          UI.ChangeWidget(
            Id(:feedback_type),
            :Enabled,
            Convert.to_boolean(UI.QueryWidget(Id(:feedback), :Value))
          )
          UI.ChangeWidget(Id(:feedback_type), :Value, Id("no_type"))
        end
        if Ops.greater_than(
          Builtins.size(
            Convert.to_string(UI.QueryWidget(Id(:location), :Value))
          ),
          0
        )
          UI.ChangeWidget(Id(:source), :Enabled, false)
        else
          UI.ChangeWidget(Id(:source), :Enabled, true)
        end
        if Ops.greater_than(
          Builtins.size(
            Convert.to_string(UI.QueryWidget(Id(:source), :Value))
          ),
          0
        )
          UI.ChangeWidget(Id(:location), :Enabled, false)
        else
          UI.ChangeWidget(Id(:location), :Enabled, true)
        end
        break if ret == :save || ret == :cancel || ret == :back
      end
      ret
    end

    # Main dialog
    # @return [Symbol]
    def ScriptsDialog
      help = _(
        "<p>\n" \
        "By adding scripts to the autoinstallation process, customize the installation for\n" \
        "your needs and take control in different stages of the installation.</p>\n"
      )

      title = _("User Script Management")
      Wizard.SetContents(title, script_dialog_contents, help, true, true)

      Wizard.HideAbortButton
      Wizard.SetNextButton(:next, Label.FinishButton)
      ret = nil
      loop do
        ret = UI.UserInput

        case ret
        when :new
          Wizard.CreateDialog
          ScriptDialog(Convert.to_symbol(ret), "")
          Wizard.CloseDialog
        when :edit
          name = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          if name.nil?
            Popup.Message(_("Select a script first."))
            next
          else
            Wizard.CreateDialog
            ScriptDialog(Convert.to_symbol(ret), name)
            Wizard.CloseDialog
          end
        when :delete
          name = Convert.to_string(UI.QueryWidget(Id(:table), :CurrentItem))
          if name.nil?
            Popup.Message(_("Select a script first."))
            next
          else
            AutoinstScripts.deleteScript(name)
          end
        end
        Wizard.SetContents(title, script_dialog_contents, help, true, true)
        break if ret == :next || ret == :back || ret == :cancel
      end

      Convert.to_symbol(ret)
    end
  end
end
