// Generated by CoffeeScript 1.6.3
var Template,
  __slice = [].slice;

module.exports = Template = (function() {
  function Template() {}

  Template.prototype._functionIFI = function() {
    var codeBody, i, param, paramValuePairs, value;
    codeBody = arguments[0], paramValuePairs = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    return "(function (" + (((function() {
      var _i, _len, _results;
      _results = [];
      for (i = _i = 0, _len = paramValuePairs.length; _i < _len; i = ++_i) {
        param = paramValuePairs[i];
        if (i % 2 === 0) {
          _results.push(param);
        }
      }
      return _results;
    })()).join(',')) + ") {\n  " + codeBody + "\n})(" + (((function() {
      var _i, _len, _results;
      _results = [];
      for (i = _i = 0, _len = paramValuePairs.length; _i < _len; i = ++_i) {
        value = paramValuePairs[i];
        if (i % 2 !== 0) {
          _results.push(value);
        }
      }
      return _results;
    })()).join(',')) + ")";
  };

  Template.prototype._function = function() {
    var codeBody, i, param, params;
    codeBody = arguments[0], params = 2 <= arguments.length ? __slice.call(arguments, 1) : [];
    return "function (" + (((function() {
      var _i, _len, _results;
      _results = [];
      for (i = _i = 0, _len = params.length; _i < _len; i = ++_i) {
        param = params[i];
        _results.push(param);
      }
      return _results;
    })()).join(',')) + ") {\n  " + codeBody + "\n}";
  };

  Template.prototype.runTimeDiscovery = "var __isAMD = (typeof define === 'function' && define.amd),\n    __isNode = (typeof exports === 'object'),\n    __isWeb = !__isNode;\n";

  return Template;

})();
