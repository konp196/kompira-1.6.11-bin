class TypedefHandler {
    constructor(parent) {
        // operate on dynamic-form-typedef table
        this.$table = $('#dynamic-form-typedef');
        this.parent = parent
    }

    fill(field) {
        if (field) {
            const nameField = this.$table.find('input[name^="typedef-"][name$="-_0"]').last();
            nameField.val(field.name).prop('readonly', true);
            // 'display name' field
            this.$table.find('input[name^="typedef-"][name$="-_1"]').last().val(field.name);
            const $el = this.$table.find('select[name^="typedef-"][name$="-_2"]').last();
            $el.val(field.type)
            $el.trigger('change')
            this.$table.find('input[name^="typedef-"][name$="-_3"]').last().val(field.qualifier);
        }
    }

    makeNamesReadonly(readonly) {
        this.$table.find('input[name^="typedef-"][name$="-_0"]').prop('readonly', readonly);
    }

    visibleFields() {
        const displayFields = [];
        this.$table.find('input[name^="typedef-"][name$="-_0"]').each((_, elem) => {
            displayFields.push($(elem).val())
        });
        return displayFields
    }

    reload(data) {
        this.clear();
        // Other than a Jobflow object, the data is null.
        if (data === null) {
            this.parent.$addBtn.click();
        }
        // else
        $.each(data, (_, field) => {
            this.parent.$addBtn.click();
            this.fill(field)
        });
    }

    clear() {
        this.$table.find('.del-row').click();
    }
}

class DropdownButton {
    constructor(parent) {
        this.parent = parent
        this.$dropdownButton = $('<button class="btn btn-sm btn-outline-secondary dropdown-toggle" data-toggle="dropdown">')
            .append('<i class="fas fa-plus"></i> ', gettext('Add display field'), ' <span class="caret"></span>');
        this.$dropdownList = $('<div class="dropdown-menu">');
        this.$el = $('<div id="id_addfield-btn" class="btn-group">')
            .append(this.$dropdownButton, this.$dropdownList);
        // Bind event handlers
        this.$dropdownButton.on('click', () => this._openDropdown());
        this.$dropdownList.on('click', 'a', (e) => this._onListItemClick(e));
        // drop down list items container
        this._data = []
    }

    clear() {
        this.$dropdownList.empty();
    }

    reload(data) {
        this.$dropdownList.empty();
        // keep data into the internal container for future use
        this._data = data
        $.each(this._data, (i, field) => {
            this._addFieldList(field);
        });
    }

    _addFieldList(field) {
        const label = field.name + ' (' + field.display_name + ')';
        this.$dropdownList.append($('<a class="dropdown-item" href="#">').data('field_name', field.name).text(label));
    }

    _openDropdown() {
        const visibleFields = this.parent.typedefHandler.visibleFields()
        this.$dropdownList.find('a').each((i, elem) => {
            const $item = $(elem);
            const fieldName = $item.data('field_name');
            $item.toggleClass('disabled', visibleFields.includes(fieldName));
        });
    }

    _onListItemClick(event) {
        const $a = $(event.currentTarget);
        if (!$a.parent().hasClass('disabled')) {
            const name = $a.data('field_name')
            // filter field from internal container of fields, which was loaded by reload()
            const field = this._data && this._data.find(field => field.name === name);
            this.parent.$addBtn.click()
            this.parent.typedefHandler.fill(field)
        }
    }
}

class MessageBoxHandler {
    constructor() {
        this.$el = $('<span>').css({ 'margin-left': '20px', 'white-space': 'normal' });
    }

    success() {
        const doneMessage = gettext('The displayList was reset!');
        this._show(doneMessage, 'blue');
    }

    fail(error) {
        const failMessage = gettext('Failed to reset the displayList!');
        let msg = '<span class="label label-warning">ERROR</span> ' + failMessage;
        if (error) {
            msg += ' (' + error + ')';
        }
        this._show(msg, 'red');
    }

    _show(message, color) {
        this.$el.html(message).css({ color: color }).show().fadeOut(2000);
    }
}

class TypeChecker {
    constructor() {
        this.builtins = {
            Integer: ['int', 'length'],
            Float: ['float'],
            Boolean: ['has_key'],
            Datetime: ['datetime', 'now'],
            Date: ['date'],
            Time: ['time'],
            Binary: ['bytes', 'encode', 'b']
        }

        this.primitiveTypeRegex = {
            /* precedence = top>down */
            Integer: /^-?\d+$/,
            Float: /^\d+\.\d+$/,
            Boolean: /^(true|false)$/,
            // object start with ./ or ../, or /
            Object: /^(\.\.\/|\.\/|\/)/,
        };

        this.stringSubsetTypeRegex = {
            // ipv4, ipv6
            IPAddress: /^["']?(?:(?:\d{1,3}\.){3}\d{1,3}|(?:[0-9a-fA-F]{1,4}:){7}[0-9a-fA-F]{1,4})["']?$/,
            // It will block spaces which are technically allowed by RFC, but they are so rare
            EMail: /^['"]?[^\s@]+@[^\s@]+\.[^\s@]+['"]?$/,
            // http:// or https://
            URL: /^['"]?(https?):\/\/[^\s/$.?#].[^\s]*['"]?$/,
            // escape \r\n or \n
            Text: /(?:\\r\\n|\\n)/
        };
    }

    _extractDefaultValue(type, value) {
        const escapeMap = {
            r: '\r',
            n: '\n',
            t: '\t'
        };
        if (type === "Integer") {
            value = parseInt(value)
        } else if (type === "Float") {
            value = parseFloat(value)
        } else if (type === "Boolean") {
            value = value === "true"
        } else if (type === "String" || type in this.stringSubsetTypeRegex) {
            // when value start and end with ' or " then it is a string.
            // remove unnecessary ' or " and replace \', \" by ' or "
            if (/^['"].*['"]/.test(value)) {
                value = value.slice(1, -1).replace(/\\(["'rnt])/g, (_, grp)=>  {
                    // If the escape character is in the map, return its corresponding value
                    if (escapeMap.hasOwnProperty(grp)) {
                        return escapeMap[grp];
                    }
                    // For single quotes ('), double quotes ("), and unknown escape sequences, return as is
                    return grp;
                });
            } else { // otherwise difficult to decide
                value = null
            }
        }
        return value;
    }

    _getBuiltinType(value, builtinFun) {
        // Check against builtins
        for (const key in this.builtins) {
            const values = this.builtins[key];
            for (const name of values) {
                if (builtinFun(name).test(value)) {
                    return key;
                }
            }
        }

        return null;
    }

    _getPrimitiveType(value) {
        const typeEntries = Object.keys(this.primitiveTypeRegex);

        for (let i = 0; i < typeEntries.length; i++) {
            const type = typeEntries[i];
            const regex = this.primitiveTypeRegex[type];
            if (regex.test(value)) {
                return type;
            }
        }
        return null
    }

    _getPrimitiveTypeWithValue(value) {
        const defaultType = "String";

        const basicType = this._getPrimitiveType(value)
        if (basicType) {
            return [basicType, this._extractDefaultValue(basicType, value)]
        }

        const type = this._getBuiltinType(value, (builtin) => new RegExp(`^${builtin}(\\(.*\\)|'.*')$`));
        if (type) {
            // difficult to decide default value when builtins
            return [type, null];
        }

        // otherwise String
        // check against stringSubsetTypeRegex
        const subtypeEntries = Object.keys(this.stringSubsetTypeRegex);
        for (let j = 0; j < subtypeEntries.length; j++) {
            const subtype = subtypeEntries[j];
            const subtypeRegex = this.stringSubsetTypeRegex[subtype];
            if (subtypeRegex.test(value)) {
                return [subtype, this._extractDefaultValue(subtype, value)];
            }
        }
        return [defaultType, this._extractDefaultValue(defaultType, value)];
    }

    _parseComplexTypeValue(value) {
        if (!value) {
            return null
        }

        // Replace single quotes with double quotes
        const jsonStringWithDoubleQuotes = value.replace(/'/g, '"');

        try {
            return JSON.parse(jsonStringWithDoubleQuotes, (key, val, context) => {
                // In JavaScript, parseFloat(), JSON.parse(): 0.00 or *.0 is parsed without decimal part, so special treatment
                if (typeof val === 'number' && this.primitiveTypeRegex["Float"].test(context.source)) {
                    return context.source;
                }
                // when array or dictionary contains array or dictionary
                else if (key && ((val !== null && typeof val === 'object') || Array.isArray(val))) {
                    throw new Error('Unsupported value');
                }
                return val; // Otherwise, return the value as is
            });
        } catch (error) {
            return null;
        }
    }

    // When some items are different then return false, otherwise true
    _isDifferentTypeItem(arr) {
        const firstType = this._getPrimitiveType(arr[0]);
        return arr.some(item => this._getPrimitiveType(item) !== firstType);
    }

    _getArrayTypeWithValue(value) {
        const defaultType = "Array";

        // check builtins
        const type = this._getBuiltinType(value, (builtin) => new RegExp(`^\\[\\s*${builtin}(\\(|').+\\]$`));

        if (type) {
            // difficult to decide default value when builtins
            return [`${defaultType}<${type}>`, null];
        }
        // check Array<Object>
        if (/^\[\s*(\.\.\/|\.\/|\/).+\]$/.test(value)) {
            // difficult to decide default value when Array<Object> so return type only
            return [`${defaultType}<Object>`, null];
        }

        // check when json parsable
        let parsedValue = this._parseComplexTypeValue(value)

        if (!parsedValue || parsedValue.length == 0 || this._isDifferentTypeItem(parsedValue)) {
            // default value is empty so return type only
            return [defaultType, null];
        }

        // otherwise
        const [valueType, _] = this._getPrimitiveTypeWithValue(parsedValue[0]);

        // _parseComplexTypeValue() keep the float value as a string to determine *.0 as a float value
        // so need to parse float value from string
        if (valueType === "Float") {
            parsedValue = parsedValue.map(parseFloat);
        }

        return !['String', 'Text'].includes(valueType) ? [`${defaultType}<${valueType}>`, parsedValue] : [defaultType, parsedValue];
    }

    _getDictionaryTypeWithValue(value) {
        // this method will return type and default value when default values are guessable

        const defaultType = "Dictionary";

        // check builtins
        const type = this._getBuiltinType(value, (builtin) => new RegExp(`^\\{\\s*(['"]).+\\1\\s*:\\s*${builtin}(\\(|').+\\}$`));

        if (type) {
            // difficult to decide default value when builtins
            return [`${defaultType}<${type}>`, null];
        }

        // check Dictionary<Object>
        if (/^\{\s*(['"]).+\1\s*:\s*(\.\.\/|\.\/|\/).+\}$/.test(value)) {
            // difficult to decide default value when Dictionary<Object>
            return [`${defaultType}<Object>`, null];
        }

        // check when json parsable
        let parsedValue = this._parseComplexTypeValue(value)
        if (!parsedValue || Object.keys(parsedValue).length == 0 || this._isDifferentTypeItem(Object.values(parsedValue))) {
            return [defaultType, null];
        }

        const keys = Object.keys(parsedValue);
        const [valueType, _] = this._getPrimitiveTypeWithValue(parsedValue[keys[0]]);

        // _parseComplexTypeValue() keep the float value as a string to determine *.0 as a float value
        // so need to parse float value from string
        if (valueType === "Float") {
            for (let key in parsedValue) {
                parsedValue[key] = parseFloat(parsedValue[key]);
            }
        }

        return !['String', 'Text'].includes(valueType) ? [`${defaultType}<${valueType}>`, parsedValue] : [defaultType, parsedValue];
    }

    // Public interface
    getTypeWithValue(value) {
        // Array ?
        if (/^\[.*\]$/.test(value)) {
            return this._getArrayTypeWithValue(value);
        }
        // Dictionary ?
        else if (/^\{.*\}$/.test(value)) {
            return this._getDictionaryTypeWithValue(value);
        }
        // else primitive type
        return this._getPrimitiveTypeWithValue(value);
    }
}


class FormEditJs {
    constructor() {
        // Initialize
        this.typeChecker = new TypeChecker();
        this.$submitObject = $('#id_submitObject');
        this.typedefHandler = new TypedefHandler(this);
        this.$addBtn = $('a.add-row');
        this.dropdownButton = new DropdownButton(this)
        this.$refreshBtn = $('<button id="id_refresh-btn" class="btn btn-sm btn-outline-secondary" type="button">')
            .html('<i class="fas fa-sync-alt"></i> ' + gettext('Reset to defaults'));
        this.messageBox = new MessageBoxHandler()

        // default setup
        this.$addBtn.after(this.dropdownButton.$el, this.$refreshBtn, this.messageBox.$el);
        this.dropdownButton.$el.hide()
        this.$refreshBtn.hide()
        // Disable navigator temporarily
        this.oldNavigatorEnabled = kompira.config.navigator.enabled;
        kompira.config.navigator.enabled = false;

        // Event handlers
        this.$submitObject.on('select2:select', (e) => this.onTypeObjectSelected(e));
        this.$refreshBtn.on('click', () => this.refreshTypeObject(true));

        // skip fields update operation when edit
        this.refreshTypeObject(!!location.pathname.match(/\.add$/));
    }

    reloadUI(data) {
        // when jobflow. i.e: data is an array
        if (data instanceof Array) {
            this.dropdownButton.reload(data)
            const visibleFields = this.typedefHandler.visibleFields()
            // When editing, there is a possibility of an empty row
            if (visibleFields.every(element => !element)) {
                this.typedefHandler.clear()
            } else {
                this.typedefHandler.makeNamesReadonly(true)
            }

            this.$addBtn.hide()
            this.dropdownButton.$el.show()
            this.$refreshBtn.show()
        }
        // when channel
        else {
            this.typedefHandler.makeNamesReadonly(false)
            this.dropdownButton.clear()
            this.$addBtn.show()
            this.dropdownButton.$el.hide()
            this.$refreshBtn.hide()
        }
    }

    onTypeObjectSelected(event) {
        const typeId = event.params.data.id;
        this.refreshTypeObject(true, typeId);
    }

    refreshTypeObject(refreshList, typeId) {
        typeId = typeId || this.$submitObject.val();
        this.messageBox.$el.finish();
        this.$refreshBtn.attr('disabled', true);
        this.fetchTypeFields(typeId)
            .done((typedefItems) => {
                if (refreshList && typeId) {
                    this.typedefHandler.reload(typedefItems)
                    this.messageBox.success()
                }
                this.reloadUI(typedefItems)
            })
            .fail(err => this.messageBox.fail(err))
            .always(() => {
                this.$refreshBtn.attr('disabled', false)
                // when open edit page
                if (!refreshList) {
                    kompira.config.navigator.enabled = this.oldNavigatorEnabled
                }
            })
    }

    fetchTypeFields(typeId) {
        const deferred = $.Deferred();
        if (!typeId) {
            // by default not jobflow, so resolve(null)
            return deferred.resolve(null).promise();
        }
        $.ajax('/.descendant', {
            data: { type_object__in: ['/system/types/Jobflow', '/system/types/Channel'], id: typeId, include_invisible_fields: "parameters" },
            traditional: true
        })
            .done((data) => {
                if (data.results.length == 0) {
                    console.error(`fetchTypeFields(typeId=${typeId}): Type object not found!`);
                    deferred.reject("Type object not found");
                } else {
                    const typeObject = data.results[0];
                    const type = typeObject.type_object
                    const fields = typeObject.fields;
                    const parameters = fields.parameters;
                    let typedefItems = [];
                    parameters && Object.entries(parameters).forEach(([key, value]) => {
                        const [guessType, qualValue] = this.typeChecker.getTypeWithValue(value)
                        const q = qualValue !== null ? JSON.stringify({ "default": qualValue }) : null;
                        typedefItems.push({
                            name: key,
                            display_name: key,
                            type: guessType,
                            qualifier: q
                        });
                    });
                    if (type !== "/system/types/Jobflow") {
                        // other than jobflow
                        typedefItems = null
                    }
                    console.debug(`fetchTypeFields(typeId=${typeId}): abspath=${typeObject.abspath}, typedefItems=`, typedefItems);
                    deferred.resolve(typedefItems);
                }
            }).fail(e => deferred.reject(e.statusText));
        return deferred.promise();
    }
}

// Initialize FormEditJs
$(function () {
    new FormEditJs();
});
