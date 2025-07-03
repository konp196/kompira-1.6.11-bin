// required libraries:
//   jQuery.js
//   tablesorter.js
//   urlize.js
//   js.cookie.js
//   js_proc.html
//   kompira.js

(function(kompira) {
    var ProcDetail = function() {
        this.update_timeout = 0;
        this.update_timer = null;
        this.update_processes = false;
        this.config = {
            update_interval: 1000,
            update_interval_max: 5000
        };
        this.$proc_control_btn = $("#process-control-form button.control-btn");
        this.$tab_console = $('#console');
        this.$tab_result = $('#result');
        this.$tab_processes = $('#processes');
        this.$console_scroll = this.$tab_console.find('.console-scrollable');
        this.$console_loading = this.$tab_console.find('.console-loading');
        this.$console_mode = this.$tab_console.find('.console-mode');
        this.$console_samp = $('#console-samp');
        this.console_autoresize = true;
        this.console_autoscroll = true;
        this.console_autoselect = false;
        this.console_reloadable = true;
        this.console_scroll_top = 0;
        this.result_autoselect = false;
        this.$result_mode = $('#result .result-mode');
        this.$proc_result = $('#proc-result');
        this.proc_table = new kompira.FilteredProcTable('#processes');
        this.$proc_status = $("#proc-status");
    };
    var is_select_node = function(nodeId) {
        if (window.getSelection) {
            const selection = window.getSelection();
            if (selection.rangeCount) {
                const range = selection.getRangeAt(0);
                const selected = range.commonAncestorContainer.id == nodeId;
                return selected;
            }
        } else {
            console.warn("Selection API not supported");
        }
        return false;
    };
    var select_node_contents = function(nodeId, toggle) {
        // https://stackoverflow.com/questions/985272/selecting-text-in-an-element-akin-to-highlighting-with-your-mouse
        if (window.getSelection) {
            const selection = window.getSelection();
            if (toggle) {
                const node = document.getElementById(nodeId);
                const range = document.createRange();
                range.selectNodeContents(node);
                selection.removeAllRanges();
                selection.addRange(range);
            } else {
                selection.removeAllRanges();
            }
            return toggle;
        } else {
            console.warn("Selection API not supported");
        }
        return false;
    };

    ProcDetail.prototype = {
        constructor: ProcDetail,
        status_text: {
            "NEW": gettext("NEW"),
            "READY": gettext("READY"),
            "RUNNING": gettext("RUNNING"),
            "WAITING": gettext("WAITING"),
            "ABORTED": gettext("ABORTED"),
            "DONE": gettext("DONE"),
        },

        init: function() {
            var self = this;
            this.datetime_format = UTILS.moment_format(get_format('DATETIME_FORMAT'));

            // タブ切り替え時のハンドラ登録
            $('#proc-tab a[data-toggle="tab"]')
                .on('show.bs.tab', function(e){
                    var tab = e.relatedTarget.id;
                    if (tab == 'tab-console') {
                        // コンソールのスクロール位置の記憶
                        self.console_scroll_top = self.$console_scroll.scrollTop();
                        self.console_autoresize = false;
                    } else if (tab == 'tab-processes') {
                        // プロセスポーリング停止
                        self.update_processes = false;
                    }
                })
                .on('shown.bs.tab', function(e){
                    var tab = e.target.id;
                    if (tab == 'tab-console') {
                        // コンソールサイズを再計算させる (resize 前に小さくしておく)
                        self.console_autoresize = true;
                        self.$console_scroll.outerHeight(10);
                        $(window).trigger('resize');
                        // コンソールのスクロール位置の復元
                        self.$console_scroll.scrollTop(self.console_scroll_top);
                    } else if (tab == 'tab-processes') {
                        // プロセスポーリング開始
                        self.update_processes = true;
                        self.updateContents();
                    }
                });

            // コンソールバッファスクロール時のイベントハンドラ登録
            this.$console_scroll.on('scroll', function(){self.consoleScroll();});
            // コンソールサイズ自動調整ハンドラ登録
            $('.alert').on('closed.bs.alert', function(){self.consoleResize()});
            $(window).on('resize', function(){self.consoleResize()});
            // コンソールバッファのリサイズと一番下へのスクロール
            this.consoleResize();
            this.$console_scroll.scrollTop(this.$console_scroll.prop('scrollHeight'));

            // プロセス制御ボタン
            this.$proc_control_btn.on('click', function(e){
                var action = $(this).val();
                self[action + 'Process']();
                return false;
            });

            // 子プロセス一覧
            this.proc_table.pathname = window.location.pathname + '.children';
            this.proc_table.hash = '#processes';
            this.proc_table.init();
            this.update_processes = window.location.hash == '#processes';

            // モード設定の更新指示
            $("#id_modify_form-modify_config")
                .on('change', function(e){
                    var checked = $(this).prop('checked');
                    $("#id_config_form-step_mode").attr('disabled', !checked).closest('tr').toggleClass('deadlink', !checked);
                    $("#id_config_form-checkpoint_mode").attr('disabled', !checked).closest('tr').toggleClass('deadlink', !checked);
                    $("#id_config_form-monitoring_mode").attr('disabled', !checked).closest('tr').toggleClass('deadlink', !checked);
                })
                .trigger('change');

            // ソースコードを prettify する
            kompira.source.prettify(true);

            // プロセスが終了していないときの処理
            // ・コンソールバッファのリロードを許可
            // ・プロセス詳細データを更新する(Ajax)
            var finished = this.getFinished();
            this.consoleReloadable(!finished);
            if (!finished) {
                this.updateContents();
            }

            // キーバインドの設定
            var isscript = this.$proc_status.data('isscript') == 'True';
            kompira.keybind
                .on('F6', function(){self.terminateProcess(true)}, gettext('terminate process'), 100)
            if (!isscript) kompira.keybind
                .on('F7', function(){self.suspendProcess()}, gettext('suspend process'), 100)
                .on('F8', function(){self.resumeProcess()}, gettext('resume process'), 100);
            kompira.keybind
                .on('Ctrl-[', function(){self.switchTab(false)}, gettext('switch prev tab'), 200)
                .on('Ctrl-]', function(){self.switchTab(true)}, gettext('switch next tab'), 200)
                .on('a', function(){self.toggleSelection()}, gettext('toggle text selection on the console tab or the result tab'), 300);
        },
        cancelTimer: function() {
            // 更新タイマをキャンセルする
            if (this.update_timer !== null) {
                clearTimeout(this.update_timer);
                this.update_timer = null;
            }
        },
        processControl: function(action, config) {
            var csrftoken = Cookies.get("csrftoken");
            var self = this;
            this.cancelTimer();
            // AJAX でプロセス制御する
            return $.ajax({
                url: window.location.pathname + "." + action,
                type: "post",
                data: config,
                headers: {
                    Accept: "application/json",
                    "X-CSRFToken": csrftoken
                }
            }).fail(function(e){
                console.error(e);
            }).always(function(){
                // プロセス制御が完了したらプロセス情報を更新する
                self.updateContents();
            });
        },
        confirmAction: function(operation) {
            var $deferred = $.Deferred();
            var $dialog = $('#confirm-dialog');
            var message = $dialog.find(".original_message").text();
            message = message.replace(/\[\[operation\]\]/g, operation);
            $dialog.find(".message").text(message);
            $dialog
                .one('click', 'button.btn-primary', function(e){
                    $deferred.resolve();
                    $dialog.modal('hide');
                    return false;
                })
                .one('shown.bs.modal', function(e){
                    $dialog.find('button.btn-primary').focus();
                })
                .one('hidden.bs.modal', function(e){
                    $deferred.reject();
                    $dialog.off('click');
                });
            $dialog.modal('show');
            return $deferred.promise();
        },
        terminateProcess: function(confirm) {
            if (!this.getFinished()) {
                var self = this;
                var control = function() {
                    self.$proc_control_btn.attr('disabled', true);
                    self.processControl('terminate');
                };
                if (confirm) {
                    this.confirmAction(gettext('terminate process')).done(control);
                } else{
                    control();
                }
            }
        },
        suspendProcess: function() {
            if (!this.getFinished()) {
                this.$proc_control_btn.attr('disabled', true);
                this.processControl('suspend');
            }
        },
        resumeProcess: function() {
            if (!this.getFinished()) {
                var config = {};
                if ($("#id_modify_form-modify_config").prop('checked')) {
                    config.step_mode = $("#id_config_form-step_mode").prop('checked');
                    config.checkpoint_mode = $("#id_config_form-checkpoint_mode").prop('checked');
                    config.monitoring_mode = $("#id_config_form-monitoring_mode").val();
                }
                this.$proc_control_btn.attr('disabled', true);
                this.processControl('resume', config);
            }
        },
        consoleResize: function() {
            // コンソールバッファをリサイズする
            if (this.console_autoresize) {
                var offset = this.$console_scroll.offset();
                this.$console_scroll.outerHeight($(document).innerHeight() - offset.top - offset.left);
            }
        },
        consoleScroll: function(event) {
            // コンソールバッファがスクロールされたとき、
            // スクロール位置によって自動スクロールモードを切り替える
            var ch = this.$console_scroll.prop('clientHeight'); // 表示領域の高さ
            var sh = this.$console_scroll.prop('scrollHeight'); // スクロール領域の高さ
            var st = this.$console_scroll.scrollTop(); // スクロール領域のトップ位置
            var fh = 16; // スクロール位置の判定にフォントサイズ分の余裕を持たせる
            // スクロール領域の一番下に達していないときは autoscroll しない
            var autoscroll = ch + st + fh >= sh;
            // autoscroll が変化するとき consoleToggle を呼び出す
            if (this.console_autoscroll != autoscroll) {
                this.consoleToggle(autoscroll);
            }
        },
        consoleToggle: function(autoscroll){
            // 自動スクロールモードに応じてアイコンの表示を切り替える
            this.$console_loading.toggle(autoscroll);
            this.console_autoscroll = autoscroll;
            // スクロール停止している間にプロセス状態が変化している場合があるので、
            // 自動スクロールを再開するときはデータを即時更新する（タイマはキャンセルする）
            if (autoscroll && this.console_reloadable) {
                this.updateContents();
            }
        },
        consoleReloadable: function(reloadable) {
            // リロード不可に設定されたときは .console-mode を非表示にする
            this.$console_mode.toggle(reloadable);
            this.console_reloadable = reloadable;
        },
        consoleSelect: function(toggle) {
            // コンソールバッファを全選択または選択解除する
            const nodeId = 'console-samp';
            if (select_node_contents(nodeId, toggle)) {
                // MEMO: 全選択した場合は console_autoselect=true にして consoleIsSelected() でのチェックを有効にする
                this.console_autoselect = true;
            }
        },
        consoleIsSelected: function() {
            const nodeId = 'console-samp';
            var selected = false;
            if (this.console_autoselect) {
                // MEMO: 意図せず range.commonAncestorContainer が変化して選択していると誤認する場合があるので、
                // this.console_autoselect が true の場合だけチェックし、未選択だと判断した場合は次回はチェックしないようにする。
                this.console_autoselect = selected = is_select_node(nodeId);
            }
            return selected;
        },
        resultSelect: function(toggle) {
            const nodeId = 'proc-result';
            if (select_node_contents(nodeId, toggle)) {
                this.result_autoselect = true;
            }
        },
        resultIsSelected: function() {
            const nodeId = 'proc-result';
            var selected = false;
            if (this.result_autoselect) {
                this.result_autoselect = selected = is_select_node(nodeId);
            }
            return selected;
        },
        toggleProcesses: function() {
            $('#selectAll').click();
        },
        toggleSelection: function(){
            // テキストの選択または解除（表示しているタブごと）
            if (this.$tab_console.hasClass('active')) {
                this.consoleSelect(!this.consoleIsSelected());
            } else if (this.$tab_result.hasClass('active')) {
                this.resultSelect(!this.resultIsSelected());
            } else if (this.$tab_processes.hasClass('active')) {
                this.toggleProcesses();
            }
        },
        switchTab: function(forward){
            // 表示するタブを前または次に切り替える
            var $activeTab = $("#proc-tab .nav-link.active").parent();
            var $targetTab = forward ? $activeTab.next() : $activeTab.prev();
            $targetTab.find('.nav-link').click();
        },
        reloadSource: function(job_path) {
            // job_path で指定したジョブを取得して、ソースを prettify して表示する
            $.ajax({
                url: job_path,
                dataType : "json",
                ifModified: true
            }).done(function(job_data) {
                $("#source").text(job_data.fields.source).removeClass('prettyprinted deadlink').addClass('prettyprint linenums');
                kompira.source.prettify(true);
            }).fail(function(xhr, status, error) {
                $("#source").text(xhr.responseText).removeClass('prettyprinted prettyprint linenums').addClass('deadlink');
            }).always(function(){
                $('#code-path').text(job_path).attr('href', job_path);
            });
        },
        getFinished: function() {
            return this.$proc_status.data('finished') == 'True';
        },
        renderProcControl: function(data) {
            var finished = !!data.finished_time;
            var suspended = !!data.suspended;
            var isscript = this.$proc_status.data('isscript') == 'True';
            var $modify_config = isscript ? null : $("#id_modify_form-modify_config");
            var modify_config_form = false;

            // プロセスの状態に応じて制御ボタンの有効化／無効化
            if (finished) {
                // 完了: 中止不可、停止不可、再開不可
                $("#id_terminate-btn").attr('disabled', true);
                if (!isscript) {
                    $("#id_suspend-btn").attr('disabled', true);
                    $("#id_resume-btn").attr('disabled', true);
                    $modify_config.attr('disabled', true);
                    modify_config_form = true;
                }
            } else if (suspended) {
                // 停止: 中止可能、停止不可、再開可能
                $("#id_terminate-btn").attr('disabled', false);
                if (!isscript) {
                    $("#id_suspend-btn").attr('disabled', true);
                    $("#id_resume-btn").attr('disabled', false);
                    if ($modify_config.attr('disabled')) {
                        $modify_config.attr('disabled', false);
                        modify_config_form = true;
                    }
                }
            } else {
                // 実行中: 中止可能、停止可能、再開不可
                $("#id_terminate-btn").attr('disabled', false);
                if (!isscript) {
                    $("#id_suspend-btn").attr('disabled', false);
                    $("#id_resume-btn").attr('disabled', true);
                    if (!$modify_config.attr('disabled')) {
                        $modify_config.attr('disabled', true);
                        modify_config_form = true;
                    }
                }
            }
            // モード設定の更新
            if (!isscript) {
                // 設定変更フィールドの有効化／無効化
                if (modify_config_form) {
                    $("#id_config_form-step_mode").prop('checked', data.config.step_mode);
                    $("#id_config_form-checkpoint_mode").prop('checked', data.config.checkpoint_mode);
                    $("#id_config_form-monitoring_mode").val(data.config.monitoring_mode).trigger('change');
                    $modify_config.prop('checked', false).trigger('change');
                }
                $('#proc-config-step-mode').text(data.config.step_mode ? 'True' : 'False');
                $('#proc-config-checkpoint-mode').text(data.config.checkpoint_mode ? 'True' : 'False');
                $('#proc-config-monitoring-mode').text(data.config.monitoring_mode);
            }
        },
        renderProcStatus: function(status, finished, suspended) {
            // プロセスステータスの更新
            if (!finished && suspended) {
                status = status + " (" + gettext('suspended') + ")";
            }
            this.$proc_status.text(status);
            this.$proc_status.data('finished', finished ? 'True' : 'False');
            this.$proc_status.data('suspended', suspended ? 'True' : 'False');
        },
        renderProcProperty: function(data) {
            // プロセスステータスの更新
            var status = this.status_text[data.status] || data.status;
            var finished = !!data.finished_time;
            var suspended = !!data.suspended;
            if (!finished && suspended) {
                status = status + " (" + gettext('suspended') + ")";
            }
            this.$proc_status.text(status);
            this.$proc_status.data('finished', finished ? 'True' : 'False');
            this.$proc_status.data('suspended', suspended ? 'True' : 'False');
            // プロセス情報の更新
            var started_time = data.started_time ? moment(data.started_time).format(this.datetime_format) : '';
            var finished_time = data.finished_time ? moment(data.finished_time).format(this.datetime_format) : '';
            var elapsed_time = data.elapsed_time ? UTILS.elapsed_time(data.elapsed_time) : '';
            $("#proc-jobflow-path").text(data.job).attr('href', data.job);
            $("#proc-user").text(data.user);
            $("#proc-started-time").text(started_time);
            $("#proc-finished-time").text(finished_time);
            $("#proc-elapsed-time").text(elapsed_time);
            $("#proc-parent").text(data.parent ? data.parent.pid : '').attr('href', data.parent ? data.parent.abspath : '');
        },
        renderJob: function(data) {
            // 実行中ジョブと行番号を更新
            if (data.lineno) {
                $("#source-lineno").text(data.lineno);
            }
            if ($('#code-path').attr('href') != data.current_job) {
                // 実行中ジョブフローのパスが変化したときはソース表示を更新する
                this.reloadSource(data.current_job);
            } else {
                // パスが変化しなくても、実行行は変化する可能性があるので highlightLine() を呼び出す
                kompira.source.highlightLine();
            }
        },
        renderResult: function(data) {
            // 結果の更新
            var finished = !!data.finished_time;
            this.$result_mode.toggle(!finished);
            this.$proc_result.text(finished ? JSON.stringify(data.result, null, 4): '').toggle(finished);
        },
        renderConsole: function(data) {
            // コンソールの更新
            if (this.console_autoscroll) {
                var finished = !!data.finished_time;
                // 自動スクロールが有効なときだけコンソールテキストを更新して一番下にスクロールする
                data.console = data.console.replace(/\r\n?/g, "\n");
                this.$console_samp.html(urlize(data.console, {autoescape: true}));
                this.$console_scroll.scrollTop(this.$console_scroll.prop('scrollHeight'));
                // 自動スクロールが有効かつ、プロセス終了時にはリローダブルを無効化する
                // ※ this.console_autoscroll が false のときは再開によるリロードがあるのでまだ有効なまま
                this.consoleReloadable(!finished);
                // コンソールが選択されているときは、更新されたコンソールを選択しなおす
                if (this.consoleIsSelected()) {
                    this.consoleSelect(true);
                }
            }
        },
        renderDetail: function(data) {
            // プロセス詳細画面の更新
            this.renderProcControl(data);
            this.renderProcProperty(data);
            this.renderResult(data);
            this.renderJob(data);
            this.renderConsole(data);
        },
        updateContents: function() {
            var self = this;
            this.cancelTimer();
            $.when(this.updateDetail(), this.updateChildren())
                .fail(function(){
                    // AJAX エラー時はタイムアウト時間を最長にする
                    self.update_timeout = self.config.update_interval_max;
                })
                .always(function(){
                    // タイムアウト時間が設定されていれば、データ更新タイマをセットする
                    if (self.update_timeout > 0) {
                        self.update_timer = setTimeout(function(){
                            self.updateContents();
                            self = null;
                        }, self.update_timeout);
                    }
                });
        },
        getDetail: function() {
            var path = window.location.pathname;
            var data = {
                timestamp: new Date().getTime()
            };
            return $.ajax(path, {
                dataType : "json",
                data : data,
                ifModified: true
            });
        },
        updateDetail: function() {
            var self = this;
            return this.getDetail()
                .done(function(data) {
                    self.renderDetail(data);
                    if (data.finished_time) {
                        // 完了状態になったとき、タイムアウト時間をクリアし、削除ボタンを有効化する
                        self.update_timeout = 0;
                        $("#id_delete-btn").prop('disabled', false);
                    } else {
                        // 完了状態でないときは、タイムアウト時間を再設定する
                        self.update_timeout += self.config.update_interval;
                        if (self.update_timeout > self.config.update_interval_max) {
                            self.update_timeout = self.config.update_interval_max;
                        }
                    }
                    self = data = null;
                });
        },
        updateChildren: function() {
            if (this.update_processes) {
                return this.proc_table.updateData();
            } else {
                return $.Deferred().resolve();
            }
        }
    };

    kompira.ProcDetail = ProcDetail;
})(kompira);
