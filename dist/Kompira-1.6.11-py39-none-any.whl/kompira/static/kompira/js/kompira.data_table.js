(function(kompira) {
    "use strict";
    /**
     * BaseDataTable
     */
    var BaseDataTable = function(selector) {
        selector = selector || 'table.list-table';
        this.list_table = $(selector).get(0);
        this.replace_history = true;
        this.pathname = window.location.pathname;
        this.hash = window.location.hash;
        this.row_tmpl = selector + " .row-template";
        this.jqxhr = null;
    };
    kompira.BaseDataTable = BaseDataTable;
    $.extend(BaseDataTable.prototype, {
        list_attrs: [],
        list_head_selector: 'thead',
        list_body_selector: 'tbody',
        list_foot_selector: 'tfoot',
        init: function(){
            this.list_head = $(this.list_head_selector, this.list_table).get(0);
            this.list_body = $(this.list_body_selector, this.list_table).get(0);
            this.list_foot = $(this.list_foot_selector, this.list_table).get(0);
            this.row_template = $.templates(this.row_tmpl);
            this.finishUpdate();
        },
        renderRow: function(datum, i) {
            return this.row_template.render(datum);
        },
        convertDatum: function(datum, i) {
            return datum;
        },
        updateList: function(data) {
            var rows = [];
            var count = 0;
            for (var i in data) {
                var datum = this.convertDatum(data[i], i);
                if (datum) {
                    rows.push(this.renderRow(datum, i));
                    count += 1;
                }
            }
            $(this.list_body).empty().html(rows);
        },
        getData: function(path) {
            return $.ajax(path, {
                dataType : "json",
                data : this.getParam(),
                traditional: true,
                ifModified: true
            });
        },
        getParam: function() {
            return {
                attrs: this.list_attrs,
                timestamp: new Date().getTime()
            };
        },
        getPath: function(search) {
            return this.pathname + '?' + search;
        },
        getReplacePath: function(search) {
            return window.location.pathname + '?' + search + window.location.hash;
        },
        getSearch: function(search) {
            return search === undefined ? window.location.search.slice(1) : search;
        },
        getListCount: function(){
            return this.list_body.children.length;
        },
        abortUpdate: function(){
            if (this.jqxhr !== null) {
                this.jqxhr.abort();
                this.jqxhr = null;
            }
        },
        startUpdate: function(){
            $(".page-header .data-loading").show();
        },
        finishUpdate: function(){
            $(".page-header .data-loading").hide();
        },
        updateData: function(search) {
            search = this.getSearch(search);
            var path = this.getPath(search);
            var self = this;
            this.abortUpdate();
            this.startUpdate();
            this.jqxhr = this.getData(path)
                .always(function(){
                    self.jqxhr = null;
                })
                .done(function(data, textStatus, jqXHR) {
                    self.onLoad(data, search);
                    if (self.replace_history) {
                        window.history.replaceState(null, '', self.getReplacePath(search));
                    }
                    self.finishUpdate();
                    self = data = path = search = null;
                })
                .fail(function(jqXHR, textStatus, errorThrown){
                    self.onFail(search, jqXHR);
                    self.finishUpdate();
                });
            return this.jqxhr;
        },
        onLoad: function(data, search) {
            this.updateList(data.results);
        },
        onFail: function(search, jqXHR) {
            console.error(this.constructor.name + ".onFail: status=" + jqXHR.status);
        },
    });

    /**
     * PageableDataTable
     */
    var PageableDataTable = function(selector) {
        kompira.BaseDataTable.call(this, selector + ' table.list-table');
        this.paginator = new kompira.Paginator(selector + ' .paginator');
    };
    kompira.PageableDataTable = PageableDataTable;
    UTILS.inherits(PageableDataTable, kompira.BaseDataTable);
    $.extend(PageableDataTable.prototype, {
        constructor: PageableDataTable,
        default_order_by: 'id',
        init: function(){
            var self = this;
            kompira.BaseDataTable.prototype.init.call(this);
            this.init_header();
            // kompira.paginator.js で登録された paginate ハンドラを解除して設定しなおす。
            this.paginator.init();
            $(this.paginator.paginator)
                .off('paginate')
                .on('paginate', function(e, search){
                    self.onPaginate(search);
                });
        },
        init_header: function(){
            this.updateHeader(window.location.search.slice(1));
            var self = this;
            $(this.list_head).on('click', 'th[data-order_by]', function(){
                var query = UTILS.get_url_vars();
                var cur_order_by = query['order_by'];
                var new_order_by = $(this).data('order_by');
                if (cur_order_by == new_order_by) {
                    new_order_by = '-' + new_order_by;
                }
                // console.info("paginate-order_by", cur_order_by, '->', new_order_by);
                query['order_by'] = new_order_by;
                delete query[self.paginator.page_kwd];
                // console.info("paginate-order_by", query);
                self.paginator.triggerPaginate($.param(query));
                return false;
            });
        },
        getTotalCount: function(){
            return this.paginator.get_total_count();
        },
        updateHeader: function(search){
            var query = UTILS.parse_query(search);
            var cur_order_by = query['order_by'] || this.default_order_by;
            var $headers = $("th[data-order_by]", this.list_head);
            for (var i in $headers) {
                var $th = $headers.eq(i);
                var order_by = $th.data('order_by');
                $th.toggleClass("headerSortDown", cur_order_by == order_by);
                $th.toggleClass("headerSortUp", cur_order_by == '-' + order_by);
            }
        },
        updateFooter: function(){
            var list_count = this.getListCount();
            $('.no_applicable_data', this.list_foot).toggle(list_count==0);
        },
        updatePaginator: function(data, search, page) {
            var query = UTILS.parse_query(search);
            if (!page) {
                if (query.page == 'last') {
                    // page=last のときに現在のページ番号が分からないので
                    // 前ページ URL を示す previous からページ番号を取得する
                    // TODO: API で現在のページ番号を返すようにする
                    if (data.previous) {
                        var page_kwd = this.paginator.page_kwd;
                        var prev_query = UTILS.parse_query(data.previous.split('?')[1].split('#')[0]);
                        // console.info("query=", query, "prev_query=", prev_query);
                        page = (prev_query[page_kwd] | 0 || 1) + 1;
                    } else {
                        page = 1;
                    }
                } else {
                    page = (query.page | 0) || 1;
                }
                // console.info("query=", query, "page=", page);
            }
            this.paginator.updatePaginator(page, query, data.count);
        },
        onLoad: function(data, search) {
            kompira.hide_error_dialog();
            this.updateList(data.results);
            this.updatePaginator(data, search);
            this.updateHeader(search);
            this.updateFooter();
        },
        onFail: function(search, jqXHR) {
            var self = this;
            var title = null;
            var status = jqXHR.status;
            var detail = jqXHR.responseJSON && jqXHR.responseJSON.detail;
            var message = null;
            var actions = {};
            console.error("onFail:", jqXHR.readyState, status, jqXHR.statusText, jqXHR.responseText);
            if (jqXHR.statusText == 'abort') {
                // 実行中のポーリングを自らキャンセルした場合は abort となり、これは無視する
                return;
            } else if (status == 401 || status == 403) {
                // Unauthorized, Forbidden 場合は再ログイン
                title = gettext('No authentication or authorization');
                message = gettext('Please try to re-login.');
                actions['relogin'] = gettext('Re-login');
            } else if (status == 204 || status == 404) {
                // No Content, Not Found の場合は最終ページのリロード
                title = gettext('No data on this page');
                message = gettext('Please try reloading on the last page.');
                actions['reload-last'] = gettext('Reload on the last page');
            } else if (status >= 400 && status < 500) {
                // Bad Request などのクライアントエラー
                title = gettext('Client error detected');
                if (!detail && jqXHR.responseText) {
                    message = $('<pre>').text(jqXHR.responseJSON ? JSON.stringify(jqXHR.responseJSON, null, 2) : jqXHR.responseText);
                }
            } else {
                // サーバから応答が無い、または、その他のエラー
                if (status == 0) {
                    title = gettext('No response');
                    detail = gettext('No response from server.');
                    message = gettext('Please make sure that the server is working properly.');
                } else {
                    title = gettext('Server error detected');
                    if (!detail && jqXHR.responseText) {
                        message = $('<pre>').text(jqXHR.responseJSON ? JSON.stringify(jqXHR.responseJSON, null, 2) : jqXHR.responseText);
                    }
                }
                actions['retry'] = gettext('Retry');
            }
            kompira.error_dialog(title, status, detail, message, actions).done(function(action){
                if (action == 'retry') {
                    self.paginator.triggerPaginate();
                } else if (action == 'reload-last') {
                    var query = UTILS.parse_query(search);
                    query[self.paginator.page_kwd] = 'last';
                    self.paginator.triggerPaginate($.param(query));
                } else if (action == 'relogin') {
                    var next = encodeURIComponent(window.location.pathname + window.location.search + window.location.hash);
                    window.location = '/.login?next=' + next;
                }
            });
        },
        onPaginate: function(search) {
            return this.updateData(search);
        },
        finishUpdate: function() {
            kompira.BaseDataTable.prototype.finishUpdate.call(this);
            var total_count = this.getTotalCount();
            var deletable = $('.active', this.paginator.page_filters).data('deletable');
            $('#id_selectable_delete-btn').attr('disabled', !deletable || total_count==0);
        },
    });
})(kompira);
