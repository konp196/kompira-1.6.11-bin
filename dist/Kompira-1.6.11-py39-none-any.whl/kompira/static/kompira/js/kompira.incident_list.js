(function(kompira) {
    "use strict";
    /**
     * PageableIncidentTable
     */
    var PageableIncidentTable = function(selector) {
        kompira.PageableDataTable.call(this, selector);
    };
    kompira.PageableIncidentTable = PageableIncidentTable;
    UTILS.inherits(PageableIncidentTable, kompira.PageableDataTable);
    $.extend(PageableIncidentTable.prototype, {
        constructor: PageableIncidentTable,
        list_attrs: [
            "id", "abspath", "name", "device", "service", "status",
            "alert_status", "alert_description",
            "created_date", "closed_date", "duration", "owner"
        ],
        status_text: {
            "OPENED": gettext("OPENED"),
            "WORKING": gettext("WORKING"),
            "CLOSED": gettext("CLOSED"),
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
            kompira.column_config.update_show_columns();
            $checkboxs = $(".delete-checkbox");
            for (var i in $checkboxs) {
                var checkbox = $checkboxs.get(i);
                if (checked_pids[checkbox.value]) {
                    checkbox.checked = true;
                }
            }
        },
        convertDatum: function(incident) {
            incident.status_text = this.status_text[incident.status] || incident.status;
            incident.abspath = "/incident/id_" + incident.id;
            if (incident.duration) {
                incident.duration = UTILS.elapsed_time(incident.duration);
            }
            if (incident.created_date) {
                incident.created_date = moment(incident.created_date).format(this.datetime_format);
            }
            if (incident.closed_date) {
                incident.closed_date = moment(incident.closed_date).format(this.datetime_format);
            }
            return incident;
        }
    });

})(kompira);
