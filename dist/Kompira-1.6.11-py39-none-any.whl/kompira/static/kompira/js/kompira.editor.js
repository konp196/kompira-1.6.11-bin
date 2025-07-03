(function(kompira){
    /* エディタ関係(CodeMirror) */
    var CONTAINER_CLASS_NAME = "kompira-editor-container";
    var CONTAINER_SELECTOR = "." + CONTAINER_CLASS_NAME;
    var inherit_options = ["mode", "readOnly"];

    function create_menubar(config) {
        /*
         * メニューバーを作成する
         * この時点ではキーバインドは未確定
         */
        var menu = config.menubar.menu;
        var left_elems = [];
        var right_elems = [];
        for (var menu_name in menu) {
            var menu_items = menu[menu_name];
            var $menu_label = $('<a>').addClass('nav-link').attr({href: '#', 'data-toggle': 'dropdown'}).append(menu_name);
            var $menu_list = $('<div>').addClass('dropdown-menu');
            var insert_divider = false;
            for (var i=0 ; i<menu_items.length ; i++) {
                var menu_data = menu_items[i];
                if (menu_data == '---') {
                    insert_divider = true;
                    continue;
                }
                var command = menu_data.command;
                if (config.disable_commands.indexOf(command) >= 0) {
                    continue;
                }
                if (insert_divider) {
                    $menu_list.append($('<div>').addClass('dropdown-divider'));
                    insert_divider = false;
                }
                var $a = $('<a>').prop({href: '#'}).addClass('dropdown-item cm-command').data(menu_data);
                $a.append($('<span>').addClass('keybind').append(''));
                $a.append($('<span>').addClass('command').append(command));
                $menu_list.append($a);
            }
            left_elems.push($('<li>').addClass('nav-item dropdown').append($menu_label, $menu_list));
        }
        right_elems.push($('<a>').addClass('nav-link cm-mode').css({'white-space': 'nowrap', 'cursor': 'default'}).append(''));
        var $nav_left = $('<ul>').addClass('navbar-nav mr-auto').append(left_elems);
        var $nav_right = $('<span>').addClass('navbar-nav').append(right_elems);
        // var $container = $('<div>').addClass('container').append($nav_left, $nav_right);
        // var $inner = $('<div>').addClass('navbar-inner').append($container);
        var $inner = $('<div>').addClass('navbar-collapse').append($nav_left, $nav_right);
        return $('<div>').addClass('CodeMirror-menubar navbar navbar-expand navbar-light bg-light').css({'margin-bottom': '2px'}).append($inner);
    }

    function is_editable(cm) {
        return !cm.getOption('readOnly');
    }

    function is_merge_mode(cm) {
        return !!cm.state.diffViews;
    }

    function update_menubar($container, cm) {
        /* メニューのキーバインドや有効・無効などを更新する */
        var config = $container.data('config');
        var $menubar = $container.find('.CodeMirror-menubar');
        $menubar.find('.cm-command').each(function(i, e){
            var $elem = $(e);
            var menu_data = $elem.data();
            var command = menu_data.command;
            if (command) {
                var keybinds = cm.getKeybinds(command);
                var keybind = keybinds.join(', ');
                var label = menu_data.label || config.command_to_label(cm, command);
                $elem.find('.command').text(label);
                $elem.find('.keybind').text(keybind);
            }
            var enabled = true;
            var enableIf = menu_data.enableIf;
            if (enableIf !== undefined) {
                enabled = !!enableIf(cm);
            }
            $elem.parent().toggleClass('disabled', !enabled);
        });
    }

    function switch_to_edit_mode($container, orig_cm) {
        var textarea = orig_cm.getTextArea();
        var curr_text = orig_cm.getValue();
        var orig_text = textarea.value;
        var config = $container.data('config');

        /* 現在の MergeView を閉じる */
        orig_cm._orig_toTextArea();
        textarea.value = orig_text;

        /* 新しい CodeMirror エディターを作成する */
        var options = $.extend(true, config.codemirror);
        for (var i=0 ; i<inherit_options.length; i++) {
            options[inherit_options[i]] = orig_cm.getOption(inherit_options[i]);
        }
        var cm = CodeMirror.fromTextArea(textarea, options);
        cm.setValue(curr_text);
        postsetup_codemirror(cm, config, orig_cm);

        /* CodeMirror を保持する */
        $container.data('codemirror', cm);
        kompira.editor.codemirror = cm;
        return cm;
    }

    function switch_to_merge_mode($container, orig_cm) {
        var textarea = orig_cm.getTextArea();
        var curr_text = orig_cm.getValue();
        var orig_text = textarea.value;
        var config = $container.data('config');

        /* 現在の CodeMirror エディターを閉じる */
        orig_cm._orig_toTextArea();
        textarea.value = orig_text;

        /* 新しい MergeVierw を作成する */
        var options = $.extend(true, config.codemirror, config.mergeview, {
            origLeft: orig_text,
            value: curr_text,
        });
        for (var i=0 ; i<inherit_options.length; i++) {
            options[inherit_options[i]] = orig_cm.getOption(inherit_options[i]);
        }
        var mv = CodeMirror.MergeView($container.get(0), options);

        /* MergeView の edit 部分をエディターとする */
        var cm = mv.edit;
        function save() {
            textarea.value = cm.getValue();
        }
        if (textarea.form) {
            CodeMirror.on(textarea.form, "submit", save);
            if (!options.leaveSubmitMethodAlone) {
                var form = textarea.form, realSubmit = form.submit;
                try {
                    var wrappedSubmit = form.submit = function() {
                        save();
                        form.submit = realSubmit;
                        form.submit();
                        form.submit = wrappedSubmit;
                    };
                } catch(e) {
                    console.error(e);
                }
            }
        }
        textarea.style.display = "none";

        /* MergeView.edit を fromTextArea で作成したように見せる */
        cm.save = save;
        cm.getTextArea = function() { return textarea; };
        cm.toTextArea = function() {
            save();
            textarea.parentNode.removeChild(mv.wrap);
            textarea.style.display = "";
            if (textarea.form) {
                CodeMirror.off(textarea.form, "submit", save);
                if (typeof textarea.form.submit == "function")
                    textarea.form.submit = realSubmit;
            }
        }

        /* 元のエディタのヒストリとセレクション情報を引き継ぐ */
        cm.setOption('autofocus', true);
        cm.setOption('styleActiveLine', true);
        cm.setOption('showCursorWhenSelecting', true);
        postsetup_codemirror(cm, config, orig_cm);

        /* CodeMirror と MergeView を保持する */
        $container.data('codemirror', cm);
        kompira.editor.codemirror = cm;
        return cm;
    }

    function postsetup_codemirror(cm, config, orig_cm) {
        var on_change = function(event) {
            kompira.navigator.setDirty();
            cm.off("change", on_change);
        }
        var on_option_change = function(cm, option) {
            var log_prefix = "on_option_change[" + option + "]:";
            if (option == "mode") {
                var mode = cm.getMode();
                var mode_opts = cm.doc.modeOption;
                console.debug(log_prefix, mode, mode_opts);
                if (mode_opts) {
                    var load_mode;
                    if (typeof mode_opts === "string") {
                        if (/\//.test(mode_opts)) {
                            load_mode = CodeMirror.findModeByMIME(mode_opts);
                        } else {
                            load_mode = CodeMirror.findModeByName(mode_opts);
                        }
                    } else {
                        if (mode_opts.name) {
                            load_mode = CodeMirror.findModeByName(mode_opts.name);
                        }
                        if (!load_mode && mode_opts.ext) {
                            load_mode = CodeMirror.findModeByExtension(mode_opts.ext);
                        }
                    }
                    if (load_mode && load_mode.mode != mode.name) {
                        console.log(log_prefix, "autoLoadMode=" + load_mode.mode);
                        CodeMirror.autoLoadMode(cm, load_mode.mode);
                    }
                }
                var mode_name = 'text';
                if (mode.name && mode.name !== 'null') {
                    mode_name = mode.helperType || mode.name;
                }
                if (is_merge_mode(cm)) {
                    for (var i=0 ; i<cm.state.diffViews.length ; i++) {
                        cm.state.diffViews[i].orig.setOption("mode", mode);
                    }
                }
                var $container = $(cm.getContainerElement());
                $container.attr('data-cm-mode', mode_name);
                $container.find('.cm-mode').text('[ ' + mode_name + ' ]');
            } else if (option == 'readOnly') {
                var readOnly = cm.getOption(option);
                var $container = $(cm.getContainerElement());
                console.debug(log_prefix, readOnly);
                $container.attr("disabled", !!readOnly);
                update_menubar($container, cm);
            }
        };
        var to_text_area = function() {
            var self = this;
            var textarea = self.getTextArea();
            var $container = $(self.getContainerElement());
            $container.removeData('codemirror');
            self.off("change", on_change);
            self.exitFullscreen();
            self.toTextArea = self._orig_toTextArea;
            delete self._orig_toTextArea;
            self.toTextArea();
            remove_container($container, textarea);
            if (kompira.editor.codemirror === self) {
                kompira.editor.codemirror = undefined;
            }
        };

        /* Textarea に戻すハンドラを上書き */
        cm._orig_toTextArea = cm.toTextArea;
        cm.toTextArea = to_text_area;

        /* オプション変更ハンドラでモードを表示する */
        cm.on('optionChange', on_option_change);
        for (var i=0 ; i<inherit_options.length; i++) {
            on_option_change(cm, inherit_options[i]);
        }

        /* テキストが編集されたときのハンドラの設定 */
        if (config.dirty_check && $(cm.getTextArea()).closest("form").hasClass("dirty-check")) {
            cm.on("change", on_change);
        }

        /* 以降に登録するハンドラはモードを切り替えてもユーザ定義ハンドラとして移行できるようにする */
        /* TODO: refactoring */
        cm._userdefined_handlers = [];
        cm.on = function(type, f) {
            var self = this;
            Object.getPrototypeOf(self).on.call(self, type, f);
            for (var i=0 ; i<self._userdefined_handlers.length ; i++) {
                var handler = self._userdefined_handlers[i];
                if (handler[0] == type, handler[1] == f) {
                    console.warn("cm.on: userdefined-handler registered already!", type);
                    return;
                }
            }
            console.debug("cm.on: userdefined-handler registered:", type);
            self._userdefined_handlers.push([type, f]);
        };
        cm.off = function(type, f) {
            var self = this;
            for (var i=0 ; i<self._userdefined_handlers.length ; i++) {
                var handler = self._userdefined_handlers[i];
                if (handler[0] == type, handler[1] == f) {
                    self._userdefined_handlers = self._userdefined_handlers.slice(0, i).concat(self._userdefined_handlers.slice(i + 1));
                    console.debug("cm.off: userdefined-handler unregisterd:", type);
                    break;
                }
            }
            Object.getPrototypeOf(self).off.call(self, type, f);
        };

        /* ユーザ定義ハンドラを引き継ぐ */
        if (orig_cm) {
            cm.setHistory(orig_cm.getHistory());
            cm.setSelections(orig_cm.listSelections());
            for (var i=0 ; i<orig_cm._userdefined_handlers.length ; i++) {
                var handler = orig_cm._userdefined_handlers[i];
                console.debug("postsetup_codemirror: migrate handler", handler);
                cm.on(handler[0], handler[1]);
            }
        }
    }

    function create_container(textarea, config) {
        var $container = $('<div>').addClass(CONTAINER_CLASS_NAME).attr('data-cm-for', textarea.id).data('config', config);
        /* メニューバーの作成 */
        if (config.menubar.enabled) {
            var $menubar = create_menubar(config);
            $container.append($menubar);
        }
        /* textarea を container に移動 */
        var $textarea = $(textarea);
        $container.insertBefore($textarea);
        $container.append($textarea);
        return $container;
    }

    function remove_container($container, textarea) {
        $(textarea).insertBefore($container);
        $container.remove();
    }

    function getEditorById(id) {
        var textarea = document.getElementById(id);
        var $container = $(textarea).closest(CONTAINER_SELECTOR);
        return $container.data('codemirror');
    };

    /* 対応する label が押された時のハンドラ設定 */
    $(document).on('click', 'label[for]', function(){
        var cm = getEditorById(this.getAttribute('for'));
        if (cm) {
            cm.focus();
            return false;
        }
    });

    /* コマンド指示ハンドラ */
    $(document).on('click', '.cm-command', function(e) {
        var $elem = $(this);
        var $container = $elem.closest(CONTAINER_SELECTOR);
        var disabled = $elem.parent().hasClass('disabled');
        var command = $elem.data('command');
        var cm = $container.data('codemirror');
        console.log("kompira.editor.command: command=" + command + (disabled ? " (disabled)" : ""));
        if (cm && !disabled) {
            /* コマンドを実行してダイアログが開かなければエディタにフォーカスを戻す */
            cm.execCommand(command);
            setTimeout(function() {
                if ($container.find('.dialog-opened').length == 0) {
                    cm.focus();
                }
            }, 100);
        }
    });

    CodeMirror.defineExtension("lookupKeys", function(key) {
        var extraKeys = this.getOption("extraKeys");
        var founds = [];
        if (key in extraKeys) {
            founds.push(extraKeys[key]);
        }
        var keyMapName = this.getOption("keyMap");
        var result = CodeMirror.lookupKey(key, keyMapName, function(cmd){
            founds.push(cmd);
            return true;
        });
        if (result === "multi") {
            founds.push("...");
        }
        return founds;
    });
    CodeMirror.defineExtension("listKeybinds", function() {
        var extraKeys = this.getOption("extraKeys");
        var keybinds = [];
        for (var key in extraKeys) {
            keybinds.push({key: key, command: extraKeys[key]});
        }
        var keyMapName = this.getOption("keyMap");
        while (keyMapName) {
            var keyMap = CodeMirror.keyMap[keyMapName];
            if (!keyMap) break;
            for (var key in keyMap) {
                if (key !== "fallthrough") {
                    keybinds.push({key: key, command: keyMap[key]});
                }
            }
            keyMapName = keyMap["fallthrough"];
        }
        return keybinds;
    });
    CodeMirror.defineExtension("getKeybinds", function(command, skip_lookup) {
        var extraKeys = this.getOption("extraKeys");
        var keybinds = [];
        var foundKeys = [];
        // extraKeys は keyMap より優先して適用される
        for (var key in extraKeys) {
            if (extraKeys[key] === command) {
                keybinds.push(key);
            }
        }
        // keyMap から指定されたコマンドに対応するキーを検索する
        var keyMapName = this.getOption("keyMap");
        while (keyMapName) {
            var keyMap = CodeMirror.keyMap[keyMapName];
            if (!keyMap) break;
            for (var key in keyMap) {
                if (key !== "fallthrough" && keyMap[key] === command) {
                    foundKeys.push(key);
                }
            }
            keyMapName = keyMap["fallthrough"];
        }
        // 取得したキーを lookupKey して実際に実行されるコマンドかチェックする
        if (!skip_lookup) {
            var lookupKeys = [];
            for (var i=0 ; i<foundKeys.length ; i++) {
                var key = foundKeys[i];
                var cmd = this.lookupKeys(key);
                if (cmd.length && cmd[0] == command) {
                    lookupKeys.push(key);
                }
            }
            keybinds = keybinds.concat(lookupKeys);
        } else {
            keybinds = keybinds.concat(foundKeys);
        }
        return keybinds;
    });
    CodeMirror.defineExtension("getContainerElement", function() {
        return $(this.getTextArea()).closest(CONTAINER_SELECTOR).get(0);
    });
    CodeMirror.commands.toggleMergeMode = function(cm) {
        var $container = $(cm.getContainerElement());
        if (is_merge_mode(cm)) {
            cm = switch_to_edit_mode($container, cm);
        } else {
            cm = switch_to_merge_mode($container, cm);
        }
        update_menubar($container, cm);
        cm.focus();
    };
    CodeMirror.commands.autocomplete = function(cm) {
        cm.showHint({hint: CodeMirror.hint.anyword});
    };
    CodeMirror.commands.toggleCommentIndented = function(cm) {
        cm.toggleComment({commentBlankLines: true, indent: true});
    };

    kompira.editor = {
        codemirror: null,

        create: function(id, config) {
            var textarea = document.getElementById(id);

            /* コンテナを作成してそこに textarea を移動させる */
            config = $.extend(true, {}, kompira.config.editor, config || {});
            var $container = create_container(textarea, config);

            /* Textarea から CodeMirror エディタを作成する */
            var cm = CodeMirror.fromTextArea(textarea, config.codemirror);
            postsetup_codemirror(cm, config);
            $container.data('codemirror', cm);
            kompira.editor.codemirror = cm;
            /* メニューバーを更新する */
            update_menubar($container, cm);
            return cm;
        },
        createAll: function(selector, config) {
            selector = selector || "textarea";
            $(selector).each(function(){
                kompira.editor.create(this.id, config);
            });
        },
        get: function(id) {
            var cm = getEditorById(id);
            if (!cm) {
                console.warn("kompira.editor.get: codemirror not found for #" + id);
            }
            return cm;
        },
        delete: function(id) {
            var cm = getEditorById(id);
            if (cm) {
                cm.toTextArea();
            } else {
                console.warn("kompira.editor.delete: codemirror not found for #" + id);
            }
        },
    };

    var pcExtraKeys = {
        "F11": "toggleFullscreen",
        "F9": false,
        "Ctrl-F9": false,
        "F8": "toggleMergeMode",
        "Ctrl-Space": "autocomplete",
        "Alt-[": "goPrevDiff",
        "Alt-]": "goNextDiff",
    };
    var macExtraKeys = {
        "F9": "toggleFullscreen",
        "F8": "toggleMergeMode",
        "F5": false,
        "Cmd-F5": false,
        "Alt-Space": "autocomplete",
        "Alt-[": "goPrevDiff",
        "Alt-]": "goNextDiff",
    };
    var mac = CodeMirror.keyMap.default == CodeMirror.keyMap.macDefault;
    var extraKeys = mac ? macExtraKeys : pcExtraKeys;

    kompira.config.editor = {
        codemirror: {
            styleActiveLine: true,
            autoCloseBrackets: true,
            matchBrackets: true,
            lineNumbers: true,
            lineWrapping: true,
            tabSize: 4,
            indentUnit: 4,
            matchBrackets: true,
            showCursorWhenSelecting: true,
            tabMode: "shift",
            autofocus: true,
            cursorScrollMargin: 32,
            foldGutter: true,
            foldOptions: {clearOnEnter: false},
            gutters: ["CodeMirror-linenumbers", "CodeMirror-foldgutter"],
            extraKeys: extraKeys,
        },
        mergeview: {
            highlightDifferences: true,
            connect: false,
            collapseIdentical: false,
            autofocus: false,
            styleActiveLine: false,
            showCursorWhenSelecting: false,
        },
        command_to_label: function(cm, command) {
            return command.replace(/([^A-Z])([A-Z])/g, "$1 $2").replace(/^[a-z]/, function(x){return x.toUpperCase()});
        },
        disable_commands: [],
        menubar: {
            enabled: true,
            menu: {
                "Edit": [
                    {command: "undo", enableIf: is_editable},
                    {command: "redo", enableIf: is_editable},
                    "---",
                    {command: "deleteLine", enableIf: is_editable},
                    {command: "joinLines", enableIf: is_editable},
                    {command: "swapLineUp", enableIf: is_editable},
                    {command: "swapLineDown", enableIf: is_editable},
                    {command: "sortLines", enableIf: is_editable},
                    "---",
                    {command: "upcaseAtCursor", enableIf: is_editable},
                    {command: "downcaseAtCursor", enableIf: is_editable},
                    "---",
                    {command: "indentMore", enableIf: is_editable},
                    {command: "indentLess", enableIf: is_editable},
                    {command: "indentAuto", enableIf: is_editable},
                    "---",
                    {command: "toggleCommentIndented", enableIf: is_editable},
                ],
                "Find": [
                    {command: "find"},
                    {command: "findPrev"},
                    {command: "findNext"},
                    "---",
                    {command: "replace"},
                    {command: "replaceAll"},
                ],
                "Selection": [
                    {command: "selectAll"},
                    {command: "selectLine"},
                    {command: "selectNextOccurrence"},
                    {command: "splitSelectionByLine"},
                    "---",
                    {command: "addCursorToPrevLine"},
                    {command: "addCursorToNextLine"},
                    "---",
                    {command: "singleSelectionTop"},
                ],
                "Go": [
                    {command: "jumpToLine"},
                    {command: "goToBracket"},
                    "---",
                    {command: "goPrevDiff", enableIf: is_merge_mode},
                    {command: "goNextDiff", enableIf: is_merge_mode},
                ],
                "View": [
                    {command: "fold"},
                    {command: "foldAll"},
                    {command: "unfold"},
                    {command: "unfoldAll"},
                    "---",
                    {command: "showInCenter"},
                    "---",
                    {command: "toggleFullscreen"},
                    "---",
                    {command: "toggleMergeMode"},
                ],
            },
        },
        dirty_check: true,
    };
})(kompira);
