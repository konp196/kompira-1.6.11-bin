// CodeMirror, copyright (c) by Marijn Haverbeke and others
// Distributed under an MIT license: https://codemirror.net/LICENSE

(function(mod) {
  if (typeof exports == "object" && typeof module == "object") // CommonJS
    mod(require("../../lib/codemirror"));
  else if (typeof define == "function" && define.amd) // AMD
    define(["../../lib/codemirror"], mod);
  else // Plain browser env
    mod(CodeMirror);
})(function(CodeMirror) {
    "use strict";
    var with_unicode_regex = 'u';
    try {
        new RegExp('\\p{Letter}', with_unicode_regex);
    } catch {
        console.warn("unicode pattern not supported")
        with_unicode_regex = undefined;
    }
    var reservedKeywords = [
        'and', 'break', 'case', 'choice', 'continue', 'elif', 'else',
        'false', 'for', 'fork', 'if', 'in', 'not', 'null', 'or', 'pfor',
        'session', 'then', 'true', 'try', 'while'
    ];
    var builtinLocalJobs = [
        'self', 'print', 'sleep', 'exit', 'return', 'abort', 'assert',
        'suspend', 'urlopen', 'mailto', 'download', 'upload'
    ];
    var builtinRemoteJobs = [
        'put', 'get', 'reboot'
    ];
    var builtinFunctions = [
        'now', 'current', 'data', 'time', 'timedelta', 'int', 'float',
        'pattern', 'path', 'user', 'group', 'string', 'type', 'decode',
        'encode', 'length', 'has_key', 'json_parse', 'json_dump',
        'mail_parse', 'iprange'
    ];
    var arrows = ['->', '=>', '->>', '=>>'];
    var specialVariables = ['STATUS', 'RESULT', 'ERROR', 'DEBUG'];

    // TODO: 識別子の正規表現パターンの検証
    var re_identifier;
    if (with_unicode_regex) {
        re_identifier = '[\\p{Letter}_][\\p{Letter}\\p{Number}_]*';
    } else {
        re_identifier = '([^\\W0-9]\\w*)';
    }
    var re_rel_path = '(\\./|\\.\\./)';
    var re_path_id = '(/|' + re_rel_path + ')' + '(' + re_identifier + '/|' + re_rel_path + ')*' + '(' + re_identifier + '|' + re_rel_path + ')' + '|' + re_rel_path;

    // MEMO: defineSimpleMode で unicode フラグを指定できるように simple.js を修正している
    //       codemirror/addon/mode/simple.js -> js/codemirror-fixed-simple.js
    CodeMirror.defineSimpleMode("jobflow", {
        start: [
            {regex: /\s+/, token: "space"},
            {regex: /\d+/, token: "number"},
            {regex: /[egr]?"""/, token: "string", next: "string_dq"},
            {regex: /[egr]?'''/, token: "string", next: "string_sq"},
            {regex: /[egr]?"(?:[^\\]|\\.)*?(?:"i?|$)/, token: "string"},
            {regex: /[egr]?'(?:[^\\]|\\.)*?(?:'i?|$)/, token: "string"},
            {regex: /#.*/, token: "comment"},
            {regex: new RegExp('(?:' + reservedKeywords.join('|') + ')\\b'), token: "atom"},
            {regex: new RegExp('(?:' + builtinLocalJobs.join('|') + ')\\b'), token: "builtin"},
            {regex: new RegExp('(?:' + builtinRemoteJobs.join('|') + ')\\b'), token: "builtin"},
            {regex: new RegExp('(?:' + builtinFunctions.join('|') + ')\\b'), token: "keyword"},
            {regex: new RegExp('(?:' + arrows.join('|') + ')'), token: "keyword"},
            {regex: new RegExp(re_path_id, with_unicode_regex), token: "link"},
            {regex: /(\+|-|\*|\\|%|\/|<|>|<=|>=|==|!=|=~|!~)/, token: "operator"},
            {regex: /(\||\,|\.|=|>>|<<|\?|\?\?|:)/, token: "operator"},
            {regex: /[\{\[\(]/, token: "operator", indent: true},
            {regex: /[\}\]\)]/, token: "operator", dedent: true},
            {regex: /__\w+__/, token: "variable-2"},
            {regex: new RegExp('\\$(' + specialVariables.join('|') + ')\\b'), token: "variable-2"},
            {regex: new RegExp(re_identifier, with_unicode_regex), token: "variable"},
            {regex: /.+/, token: "error"},
        ],
        string_dq: [
            {regex: /(?:[^\\]|\\.)*?"""i?/, token: "string", next: "start"},
            {regex: /.*/, token: "string"}
        ],
        string_sq: [
            {regex: /(?:[^\\]|\\.)*?'''i?/, token: "string", next: "start"},
            {regex: /.*/, token: "string"}
        ],
        meta: {
            lineComment: "#",
            fold: "jobflow",
            mode: "jobflow",
            spec: "text/x-jobflow",
        }
    });
});
