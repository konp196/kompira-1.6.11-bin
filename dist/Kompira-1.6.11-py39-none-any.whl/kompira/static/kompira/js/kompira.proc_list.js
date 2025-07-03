(function(kompira) {
    "use strict";
    /**
     * PageableProcTable
     */
    var PageableProcTable = function(selector) {
        kompira.PageableDataTable.call(this, selector);
    };
    kompira.PageableProcTable = PageableProcTable;
    UTILS.inherits(PageableProcTable, kompira.PageableDataTable);
    $.extend(PageableProcTable.prototype, {
        constructor: PageableProcTable,
        list_attrs: [
            "id", "abspath", "status", "suspended", "current_job",
            "started_time", "finished_time", "elapsed_time", "user"
        ],
        status_text: {
            "NEW": gettext("NEW"),
            "READY": gettext("READY"),
            "RUNNING": gettext("RUNNING"),
            "WAITING": gettext("WAITING"),
            "ABORTED": gettext("ABORTED"),
            "DONE": gettext("DONE"),
        },
        default_order_by: '-id',
        init: function(){
            kompira.PageableDataTable.prototype.init.call(this);
            this.datetime_format = UTILS.moment_format(get_format('DATETIME_FORMAT'));
        },
        updateList: function(data) {
            var checked_pids = {};
            var $checkboxs = $(".delete-checkbox");
            for (var i in $checkboxs) {
                var checkbox = $checkboxs.get(i);
                if (checkbox.checked) {
                    checked_pids[checkbox.value] = true;
                }
            }
            kompira.PageableDataTable.prototype.updateList.call(this, data);
            $checkboxs = $(".delete-checkbox");
            for (var i in $checkboxs) {
                var checkbox = $checkboxs.get(i);
                if (checked_pids[checkbox.value]) {
                    checkbox.checked = true;
                }
            }
        },
        convertDatum: function(proc) {
            proc.status_text = this.status_text[proc.status] || proc.status;
            proc.abspath = "/process/id_" + proc.id;
            if (proc.elapsed_time) {
                proc.elapsed_time = UTILS.elapsed_time(proc.elapsed_time);
            }
            if (proc.started_time) {
                proc.started_time = moment(proc.started_time).format(this.datetime_format);
            }
            if (proc.finished_time) {
                proc.finished_time = moment(proc.finished_time).format(this.datetime_format);
            }
            return proc;
        }
    });

    /**
     * PollableProcTable
     */
    function PollableProcTable(selector, interval) {
        kompira.PageableProcTable.call(this, selector);
        this.polling_timer = null;
        this.polling_interval = interval;
        this.polling_multiplier = 1;
    };
    kompira.PollableProcTable = PollableProcTable;
    UTILS.inherits(PollableProcTable, kompira.PageableProcTable);
    $.extend(PollableProcTable.prototype, {
        constructor: PollableProcTable,
        updateData: function(search) {
            var self = this;
            this.clearPolling();
            return kompira.PageableProcTable.prototype.updateData.call(this, search)
                .always(function(){
                    self.setPolling();
                    self = search = null;
                });
        },
        clearPolling: function() {
            if (this.polling_timer !== null) {
                clearTimeout(this.polling_timer);
                this.polling_timer = null;
            }
        },
        setPolling: function() {
            var self = this;
            var interval = this.polling_interval * this.polling_multiplier;
            if (interval > 0) {
                console.log("setPolling: interval=" + interval);
                this.polling_timer = setTimeout(function(){
                    self.updateData();
                    self = null;
                }, interval);
            }
        }
    });

    /**
     * FilteredProcTable
     */
    function FilteredProcTable(selector, interval) {
        kompira.PollableProcTable.call(this, selector, interval);
        this.submit_timer = null;
        this.submit_delay = 50;
        /* 日付指定はバックエンド側で処理できる範囲(0001/01/01～9999/12/31)に制限する */
        this.timeline_min = moment('00010101');
        this.timeline_max = moment('99991231');
    };
    kompira.FilteredProcTable = FilteredProcTable;
    UTILS.inherits(FilteredProcTable, kompira.PollableProcTable);
    $.extend(FilteredProcTable.prototype, {
        constructor: FilteredProcTable,
        init: function(){
            kompira.PollableProcTable.prototype.init.call(this);
            this.$process_search_form = $("#process-search-form");
            this.$datepickers = $('.datetimepicker-input', self.$process_search_form);
            this.$timeline_sta = $('#id_timeline_sta');
            this.$timeline_end = $('#id_timeline_end');
            this.init_filter_ctrl();
            this.init_datetime_ctrl();
        },
        search_form_submit: function(){
            var self = this;
            window.clearTimeout(this.submit_timer);
            this.submit_timer = window.setTimeout(function(){
              self.$process_search_form.triggerHandler('submit');
              self.submit_timer = null;
            }, this.submit_delay);
        },
        init_datetime_ctrl: function(){
            this.$timeline_end.datetimepicker('minDate', this.timeline_min);
            this.$timeline_end.datetimepicker('maxDate', this.timeline_max);
            this.$timeline_sta.datetimepicker('minDate', this.timeline_min);
            this.$timeline_sta.datetimepicker('maxDate', this.timeline_max);
        },
        init_filter_ctrl: function(){
            var self = this;
            /* 期間は sta <= end になるように制限する */
            this.$timeline_end.on("show.datetimepicker", function(e) {
                var min_value = self.$timeline_sta.datetimepicker('date') || self.timeline_min;
                self.$timeline_end.datetimepicker('minDate', min_value);
                console.log("timeline_end.show.datetimepicker: minDate=", min_value && min_value.format());
            });
            this.$timeline_sta.on("show.datetimepicker", function(e) {
                var max_value = self.$timeline_end.datetimepicker('date') || self.timeline_max;
                self.$timeline_sta.datetimepicker('maxDate', max_value);
                console.log("timeline_sta.show.datetimepicker: maxDate=", max_value && max_value.format());
            });
            this.$datepickers.on('hide.datetimepicker', function(){
                self.init_datetime_ctrl();
            });
            /* 期間指定のハンドラ設定 */
            this.$datepickers.on('change.datetimepicker', function(e) {
                // console.debug("change.datetimepicker:", e.currentTarget.name, e.oldDate && e.oldDate.format(), '=>', e.date && e.date.format());
                self.search_form_submit();
            });
            $('.timeline-link').on('click', function(e){
                self.onTimelineLink(e);
                return false;
            });
            $('.timeline-menu').on('click', '.dropdown-item', function(e){
                self.onTimelineMenu(e);
            });
            // this.finishUpdate();
            // WIP: キーバインド設定
            // kompira.keybind.on('Ctrl-Up', function(){$process_search_form.find('.timeline-prev').click()}, gettext('goto prev timeline'), 710);
            // kompira.keybind.on('Ctrl-Down', function(){$process_search_form.find('.timeline-next').click()}, gettext('goto next timeline'), 710);
        },
        onTimelineLink: function(e){
            /* 期間指定の範囲移動 */
            var go_next = $(e.currentTarget).hasClass('timeline-next');
            var sta_date = this.$timeline_sta.datetimepicker('date');
            var end_date = this.$timeline_end.datetimepicker('date');
            var move_days = 1;
            var moved = false;
            if (sta_date && end_date) {
                if (sta_date.date() == 1 && end_date.date() == end_date.daysInMonth()) {
                    /* 月初日・月末日が指定されている場合は、月単位で移動する */
                    var move_months = Math.abs((end_date.year() * 12 + end_date.month()) - (sta_date.year() * 12 + sta_date.month())) + 1;
                    if (go_next) {
                        var move_max = Math.max((this.timeline_max.year() * 12 + this.timeline_max.month()) - (end_date.year() * 12 + end_date.month()), 0);
                        move_months = Math.min(move_months, move_max);
                    } else {
                        var move_max = Math.max((sta_date.year() * 12 + sta_date.month()) - (this.timeline_min.year() * 12 + this.timeline_min.month()), 0);
                        move_months = -Math.min(move_months, move_max);
                    }
                    if (move_months != 0) {
                        sta_date.add(move_months, 'months');
                        end_date.add(move_months, 'months').add(1, 'months').date(1).add(-1, 'days');
                        moved = true;
                    }
                    move_days = 0;
                } else {
                    move_days = Math.floor(Math.abs(end_date - sta_date) / 86400000) + 1;
                }
            }
            if (move_days != 0) {
                if (!sta_date && !end_date) {
                    end_date = moment(0, 'HH');  // today, 00:00:00
                }
                if (go_next) {
                    var move_max = Math.max(Math.floor(Math.max(this.timeline_max - (end_date || sta_date)) / 86400000), 0);
                    move_days = Math.min(move_days, move_max);
                } else {
                    var move_max = Math.max(Math.floor(Math.max((sta_date || end_date) - this.timeline_min) / 86400000), 0);
                    move_days = -Math.min(move_days, move_max);
                }
                if (move_days != 0) {
                    if (sta_date) {
                        sta_date.add(move_days, 'days');
                    }
                    if (end_date) {
                        end_date.add(move_days, 'days');
                    }
                    moved = true;
                }
            }
            if (moved) {
                this.$timeline_sta.datetimepicker('date', sta_date);
                this.$timeline_end.datetimepicker('date', end_date);
            }
            // console.debug("timeline-link.click["+(go_next?"next":"prev")+"]:", sta_date && sta_date.format(), '..', end_date && end_date.format());
        },
        onTimelineMenu: function(e){
            /* メニューによる期間指定 */
            var $menu = $(e.currentTarget)
            var action = $menu.data('action');
            var sta_date = null, end_date = null;
            if (action == 'reset') {
            } else if (action == 'set-months') {
                var months = $menu.data('add-months');
                sta_date = moment(1, 'DD').add(months, 'months');
                end_date = sta_date.clone().add(1, 'months').add(-1, 'days');
            } else if (action == 'set-years') {
                var years = $menu.data('add-years');
                sta_date = moment(1, 'MM').add(years, 'years');
                end_date = sta_date.clone().add(1, 'years').add(-1, 'days');
            } else if (action == 'set-sta') {
                var days = $menu.data('add-days');
                sta_date = moment(0, 'HH').add(days, 'days');
            } else if (action == 'set-end') {
                var days = $menu.data('add-days');
                end_date = moment(0, 'HH').add(days, 'days');
            }
            this.$timeline_sta.datetimepicker('date', sta_date);
            this.$timeline_end.datetimepicker('date', end_date);
            // console.debug("timeline-menu.click["+action+"]:", sta_date && sta_date.format(), '..', end_date && end_date.format());
        },
        onLoad: function(data, search) {
            this.polling_multiplier = 1;
            kompira.PollableProcTable.prototype.onLoad.call(this, data, search);
        },
        onFail: function(search, jqXHR) {
            this.polling_multiplier = 3;
            kompira.PollableProcTable.prototype.onFail.call(this, search, jqXHR);
        },
    });
})(kompira);
