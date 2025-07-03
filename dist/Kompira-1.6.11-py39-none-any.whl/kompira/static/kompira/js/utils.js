var UTILS = (function (my, $) {
    my.inherits = function(ctor, superCtor) {
        if (ctor === undefined || ctor === null)
            throw new TypeError('The constructor to `inherits` must not be ' +
                                'null or undefined.');
        if (superCtor === undefined || superCtor === null)
            throw new TypeError('The super constructor to `inherits` must not ' +
                                'be null or undefined.');
        if (superCtor.prototype === undefined)
            throw new TypeError('The super constructor to `inherits` must ' +
                                'have a prototype.');
        ctor.super_ = superCtor;
        Object.setPrototypeOf(ctor.prototype, superCtor.prototype);
    };
    my.parse_query = function(query) {
        var vars = {};
        var hashes = query ? query.split('&') : [];
        for(var i = 0; i < hashes.length; i++) {
            var pair = hashes[i].split('=');
            pair[0] = decodeURIComponent(pair[0].replace(/\+/g, ' '));
            pair[1] = decodeURIComponent(pair[1].replace(/\+/g, ' '));
            if (typeof vars[pair[0]] === "undefined") {
                vars[pair[0]] = pair[1];
            } else if (typeof vars[pair[0]] === "string") {
                var arr = [vars[pair[0]], pair[1]];
                vars[pair[0]] = arr;
            } else {
                vars[pair[0]].push(pair[1]);
            }
        }
        return vars;
    };
    my.get_url_vars = function() {
        return my.parse_query(window.location.search.slice(1));
    };
    my.elapsed_time = function(value) {
        var seconds = Math.floor(value % 86400);
        var days = Math.floor(value / 86400);
        var hours = Math.floor(seconds / 3600);
        seconds = seconds % 3600;
        var minutes = ("00" + Math.floor(seconds / 60)).substr(-2);
        seconds = ("00" + (seconds % 60)).substr(-2);
        var time = hours + ":" + minutes + ":" + seconds;
        if (days) {
            var fmt = ngettext('%s day, %s', '%s days, %s', days);
            return interpolate(fmt, [days, time]);
        } else {
            return time;
        }
    };
    my.moment_format_table = {
        N: 'MMM.',
        Y: 'Y',
        n: 'M',
        m: 'MM',
        j: 'D',
        d: 'DD',
        G: 'H',
        H: 'HH',
        i: 'mm',
        s: 'ss'
    };
    my.moment_format = function(format) {
        return format.replace(/[A-Za-z]/g, function(s){
            return my.moment_format_table[s] || s;
        });
    };
    my.get_cookie = function(name) {
        let cookieValue = null;
        if (document.cookie && document.cookie !== '') {
            const cookies = document.cookie.split(';');
            for (let i = 0; i < cookies.length; i++) {
                const cookie = cookies[i].trim();
                // Does this cookie string begin with the name we want?
                if (cookie.substring(0, name.length + 1) === (name + '=')) {
                    cookieValue = decodeURIComponent(cookie.substring(name.length + 1));
                    break;
                }
            }
        }
        return cookieValue;
    };
    return my;
})({}, jQuery);
