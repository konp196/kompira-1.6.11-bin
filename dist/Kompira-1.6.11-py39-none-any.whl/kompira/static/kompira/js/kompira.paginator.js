(function(kompira) {
    var config = kompira.config.paginator;
    var Paginator = function(selector) {
        var $paginator = $(selector);
        this.paginator = $paginator.get(0);
        this.pathname = '';
        this.hash = $paginator.data('url_hash') || '';
        this.page_kwd = $paginator.data('page_kwd') || config.page_kwd || 'page';
        this.size_kwd = this.page_kwd + (config.size_kwd || '_size');
        this.init_size = 0|($paginator.data('page_size') || UTILS.get_url_vars()[this.size_kwd] || this.default_page_size);
        this.size_selector = $paginator.parent().find('select.page_size_selector').get(0);
        this.page_filters = $paginator.parent().find('.page_filters').get(0);
        this.form_search = $paginator.parent().find('form.form-search').get(0);
    };
    Paginator.prototype = {
        constructor: Paginator,
        first_page: 1,
        last_page: 'last',
        default_page_size: config.pagesize_default,
        init: function() {
            var self = this;
            var $paginator = $(this.paginator);
            if (!$paginator.data('initialized')) {
                $paginator.data('initialized', true);
                if (this.size_selector) {
                    this.init_size_selector();
                }
                if (this.page_filters) {
                    this.init_page_filters();
                }
                if (this.form_search) {
                    this.init_form_search();
                }
                $paginator
                    .on('click', 'a', function(){
                        var $a = $(this);
                        if (!$a.parent('li').hasClass('disabled') && !$a.hasClass('page-current')) {
                            var search = this.href.split('?')[1].split('#')[0];
                            var query = UTILS.parse_query(search);
                            // console.info("paginate-link", query);
                            self.triggerPaginate($.param(query));
                        }
                        return false;
                    })
                    .on('paginate', function(e, search){
                        // MEMO: paginate を処理する場合はこのハンドラを off すること
                        window.location.search = search;
                    });
            }
        },
        triggerPaginate: function(search) {
            if (search === undefined) {
                search = window.location.search.slice(1);
            }
            $(this.paginator).triggerHandler('paginate', search);
        },
        init_size_selector: function() {
            var self = this;
            var page_size = this.init_size;
            var $size_selector = $(this.size_selector);
            // サイズセレクタに元からあるリストを取得し、config.pagesize_list とマージする
            var values = $size_selector.find('>option').map(function(){return 0|this.value;}).get();
            values = values.concat(config.pagesize_list, 0|page_size);
            values = values.filter(function(e, i, array){ return array.indexOf(e) === i; });
            values.sort(function(a, b){return a - b;});
            // サイズセレクタの選択肢を作り直す
            $size_selector.empty();
            $.each(values, function(i, value){
                $size_selector.append($('<option>').attr('value', value).text(value));
            });
            $size_selector.selectpicker();
            $size_selector.selectpicker('val', page_size);
            $size_selector.on('change', function(){
                var $selector = $(this);
                var query = UTILS.get_url_vars();
                query[self.size_kwd] = $selector.val();
                delete query[self.page_kwd];
                // console.info("paginate-size", query);
                self.triggerPaginate($.param(query));
            });
            $size_selector = null;
        },
        init_page_filters: function() {
            var self = this;
            this.update_page_filters(UTILS.get_url_vars());
            $(this.page_filters).on('click', '> li > a', function(){
                var filters = $(this).data('filters');
                var query = UTILS.get_url_vars();
                for (var key in filters) {
                    var exp = filters[key];
                    if (exp == false) {
                        delete query[key];
                    } else {
                        query[key] = exp;
                    }
                }
                delete query[self.page_kwd];
                // console.info("paginate-filters", query);
                self.triggerPaginate($.param(query));
                return false;
            });
        },
        init_form_search: function(){
            var self = this;
            $(this.form_search).on('submit', function(e){
                var query = UTILS.get_url_vars();
                $('input.search-query', this).each(function(i, input_elem){
                    var $input = $(input_elem);
                    var key = $input.attr('name');
                    var val = $input.val();
                    if (!val) {
                        delete query[key];
                    } else {
                        query[key] = val;
                    }
                });
                delete query[self.page_kwd];
                // console.info("form_search", query, e.target);
                self.triggerPaginate($.param(query));
                return false;
            });
        },
        update_page_filters: function(query) {
            var $lis = $('> li', this.page_filters);
            for (var i in $lis) {
                var $a = $lis.eq(i).find('> a');
                var filters = $a.data('filters');
                var active = true;
                for (var key in filters) {
                    var exp = filters[key];
                    var val = query[key];
                    if (exp == false) {
                        if (val) {
                            active = false;
                            break;
                        }
                    } else if (exp != val) {
                        active = false;
                        break;
                    }
                }
                $a.toggleClass('active', active);
            }
        },
        get_page_size: function() {
            return ($(this.size_selector).val() | 0) || this.default_page_size;
        },
        get_total_count: function() {
            return $('.page-count', this.paginator).text() | 0;
        },
        _make_href: function(enabled, query, page) {
            var href = this.pathname;
            if (enabled) {
                query[this.page_kwd] = page;
                var search = $.param(query);
                if (search) {
                    href += '?' + search;
                }
            }
            href += this.hash;
            return href;
        },
        update_paginator: function(page, query, count, page_size) {
            var min_page = 1;
            var max_page = Math.ceil(count / page_size);
            var has_prev = page > min_page;
            var has_next = page < max_page;
            var sta_index = Math.min((page - 1) * page_size + 1, count);
            var end_index = Math.min(page * page_size, count);
            $(this.size_selector).selectpicker('val', page_size);
            $('.page-first', this.paginator)
                .attr('href', this._make_href(has_prev, query, this.first_page))
                .parent('li').toggleClass('disabled', !has_prev);
            $('.page-prev', this.paginator)
                .attr('href', this._make_href(has_prev, query, Math.max(page-1, min_page)))
                .parent('li').toggleClass('disabled', !has_prev);
            $('.page-current', this.paginator).attr('title', 'Page ' + page + ' / ' + max_page);
            $('.page-range', this.paginator).text('' + sta_index + '-' + end_index);
            $('.page-count', this.paginator).text('' + count);
            $('.page-next', this.paginator)
                .attr('href', this._make_href(has_next, query, Math.min(page+1, max_page)))
                .parent('li').toggleClass('disabled', !has_next);
            $('.page-last', this.paginator)
                .attr('href', this._make_href(has_next, query, this.last_page))
                .parent('li').toggleClass('disabled', !has_next);
        },
        updatePaginator: function(page, query, count, page_size) {
            page_size = page_size || query[this.size_kwd] || this.get_page_size();
            this.update_paginator(page, query, count, page_size);
            this.update_page_filters(query);
        }
    };
    kompira.Paginator = Paginator;

    /**
     * ページネータを有効化する
     */
    kompira.paginators = $('.paginator').map(function(){
        var paginator = new Paginator(this);
        paginator.init();
        return paginator;
    });
})(kompira);
