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
    CodeMirror.registerHelper("fold", "jobflow", function(cm, start) {
        var line = start.line, lineText = cm.getLine(line);
        var tokenType;

        function findOpening(openCh) {
            for (var at = start.ch, pass = 0;;) {
                var found = at <= 0 ? -1 : lineText.lastIndexOf(openCh, at - 1);
                if (found == -1) {
                    if (pass == 1) break;
                    pass = 1;
                    at = lineText.length;
                    continue;
                }
                if (pass == 1 && found < start.ch) break;
                tokenType = cm.getTokenTypeAt(CodeMirror.Pos(line, found + 1));
                if (!/^(comment|string)/.test(tokenType)) return found + 1;
                at = found - 1;
            }
        }

        /*
         * 以下のパターンの ... 部分を折りたためるようにする
         *
         *  { xxx | ... }
         *  [ xxx : ... ]
         *  [ xxx = ... ]
         */
        var startToken = "{", endToken = "}", delimTokens = ["|"], startCh = findOpening("{");
        if (startCh == null) {
            startToken = "[", endToken = "]", delimTokens = [":", "="], startCh = findOpening("[");
        }

        if (startCh == null) return;
        var count = 1, lastLine = cm.lastLine(), end, endCh;
        var delimLine = null, delimCh = null;
        outer: for (var i = line; i <= lastLine; ++i) {
            var text = cm.getLine(i), pos = i == line ? startCh : 0;
            for (;;) {
                var nextOpen = text.indexOf(startToken, pos);
                var nextClose = text.indexOf(endToken, pos);
                if (delimCh == null) {
                    for (var j=0 ; j<delimTokens.length; j++) {
                        var nextDelim = text.indexOf(delimTokens[j], pos);
                        if (nextDelim >= 0) {
                            delimLine = i, delimCh = nextDelim;
                            break;
                        }
                    }
                }
                if (nextOpen < 0) nextOpen = text.length;
                if (nextClose < 0) nextClose = text.length;
                pos = Math.min(nextOpen, nextClose);
                if (pos == text.length) break;
                if (cm.getTokenTypeAt(CodeMirror.Pos(i, pos + 1)) == tokenType) {
                    if (pos == nextOpen) ++count;
                    else if (!--count) { end = i; endCh = pos; break outer; }
                }
                ++pos;
            }
        }
        if (end == null || line == end) return;
        var from = delimCh != null ? CodeMirror.Pos(delimLine, delimCh + 1) : CodeMirror.Pos(line, startCh);
        return {from: from, to: CodeMirror.Pos(end, endCh)};
    });
});
