//
// オブジェクト選択用select2フィールドの処理
//
(function(kompira){
    function templateResult(obj) {
        if (obj.loading) {
            return obj.text;
        }
        // HeavySelect2Widget が返すデータから first_text と second_text に分離する
        // ObjectWidget:
        //    id: Object.id
        //    text: Object.display_name
        //    abspath: Object.abspath
        //
        // HeavySelect2Widget:
        //    id: enum[0]
        //    text: enum[1]
        //
        const first_text = obj.text;
        const second_text = obj.abspath || obj.id;
        return $('<div>').append(
            $('<div>').addClass('model-option-first').text(first_text),
            $('<div>').addClass('model-option-second').text(second_text != first_text ? second_text : ''));
    }
    function templateSelection(obj) {
        return obj.text;
    }
    function init_select2($element, options) {
        $element.select2(options);
    }
    function init_heavy_select2($element, options) {
        var settings = $.extend({
            ajax: {
                traditional: true,
                data: function (params) {
                    var result = {
                        term: params.term,
                        page: params.page,
                        field_id: $element.data('field_id'),
                    }
                    var dependentFields = $element.data('select2-dependent-fields');
                    var $form = $element.closest('form');
                    if (dependentFields) {
                        // 編集中フォームの依存フィールドから入力値を取得する
                        // 依存フィールドの入力値は JSON 化してパラメータに渡す
                        // TOTAL_FORMS があれば Array<T>/Dictionary<T> と判断する
                        // Dictionary<T> はキーと値を [key, val] のように配列ペアにする
                        dependentFields = dependentFields.trim().split(/\s+/);
                        depend_values = {}
                        $.each(dependentFields, function (i, dependentField) {
                            var depend_value;
                            var $total_forms = $('[name=' + dependentField + '-TOTAL_FORMS]', $form);
                            if ($total_forms.length == 0) {
                                depend_value = $('[name=' + dependentField + ']', $form).val();
                            } else {
                                depend_value = [];
                                $total_forms.parent().find('.array-item').each(function(i, item){
                                    var $item = $(item);
                                    var $widgets = $item.find('[name^=' + dependentField + '-]');
                                    if ($widgets.length == 1) {
                                        depend_value.push($widgets.val());
                                    } else if ($widgets.length == 2) {
                                        var key = $widgets.eq(0).val();
                                        var val = $widgets.eq(1).val();
                                        depend_value.push([key, val]);
                                    }
                                });
                            }
                            depend_values[dependentField] = depend_value;
                        });
                        result.depend_data = JSON.stringify(depend_values);
                    }
                    return result;
                },
                processResults: function (data, page) {
                    return {
                        results: data.results,
                        pagination: {
                            more: data.more
                        }
                    };
                }
            }
        }, options);
        $element.select2(settings);
    };
    kompira.init_select2_field = function($select2) {
        if ($select2.kompira_djangoSelect2) {
            //
            // オブジェクトモデルフィールド(heavy)のみ、選択肢をカスタマイズする
            //
            $select2.filter('.django-select2-heavy').kompira_djangoSelect2({
                theme: 'bootstrap4',
                dropdownAutoWidth: true,
                width: 'auto',
                templateResult: templateResult,
                templateSelection: templateSelection
            });
            //
            // heavy以外は通常の初期化
            //
            $select2.filter('.django-select2').not('.django-select2-heavy').kompira_djangoSelect2({
                theme: 'bootstrap4',
                dropdownAutoWidth: true,
                width: 'auto'
            });
        }
    };
    kompira.custom_select2_field = function($elem) {
        $elem.filter('.django-select2').each(function(){
            var $select2 = $(this);
            var options = $select2.data('select2').options.options;
            // options.theme = 'bootstrap4';
            options.dropdownAutoWidth = true;
            options.width = 'auto';
            if ($select2.is(('.django-select2-heavy'))) {
                options.templateResult = templateResult;
                options.templateSelection = templateSelection;
                if ($select2.val()) {
                    // 選択されている値があるときは templateSelection で再描画させるため change イベントを発火する
                    $select2.trigger('change');
                }
            }
        });
    };
    // カスタマイズ版 djangoSelect2
    $.fn.kompira_djangoSelect2 = function(options) {
        var settings = $.extend({}, options)
        $.each(this, function (i, element) {
            var $element = $(element);
            if ($element.hasClass('django-select2-heavy')) {
                init_heavy_select2($element, settings);
            } else {
                init_select2($element, settings);
            }
            // django_select2.js での select2:select ハンドラを設定する（依存フィールドが複数の場合の対応）
            $element.on('select2:select', function(e){
                var name = $(e.currentTarget).attr('name');
                $('[data-select2-dependent-fields]').each(function() {
                    var $elem = $(this);
                    if ($elem.attr('data-select2-dependent-fields').split(' ').indexOf(name) >= 0) {
                        $elem.val('').trigger('change');
                    }
                });
            });
        });
        return this;
    }
    $(function () {
        $('.django-select2').kompira_djangoSelect2();
    })
})(kompira);
