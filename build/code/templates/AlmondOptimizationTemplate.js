// Generated by CoffeeScript 1.6.3
var AlmondOptimizationTemplates, Template, l, _B,
  __hasProp = {}.hasOwnProperty,
  __extends = function(child, parent) { for (var key in parent) { if (__hasProp.call(parent, key)) child[key] = parent[key]; } function ctor() { this.constructor = child; } ctor.prototype = parent.prototype; child.prototype = new ctor(); child.__super__ = parent.prototype; return child; };

_B = require('uberscore');

l = new _B.Logger('urequire/AlmondOptimizationTemplates');

Template = require('./Template');

module.exports = AlmondOptimizationTemplates = (function(_super) {
  var _this = this;

  __extends(AlmondOptimizationTemplates, _super);

  Function.prototype.property = function(p) {
    var d, n;
    for (n in p) {
      d = p[n];
      Object.defineProperty(this.prototype, n, d);
    }
    return null;
  };

  Function.prototype.staticProperty = function(p) {
    var d, n;
    for (n in p) {
      d = p[n];
      Object.defineProperty(AlmondOptimizationTemplates.prototype, n, d);
    }
    return null;
  };

  function AlmondOptimizationTemplates(ti) {
    this.ti = ti;
  }

  AlmondOptimizationTemplates.property({
    wrap: {
      get: function() {
        var globalDep, globalVars;
        return {
          start: "// Combined file generated by uRequire v" + l.VERSION + ", with help from r.js & almond\n(function (){\n  " + this.runTimeDiscovery + "\n\n  var __global = null,\n      __nodeRequire = function(){};\n\n  if (__isNode) {\n      __nodeRequire = require;\n      __global = global;\n  } else {\n      __global = window;\n  };\n\n  factory = function() {",
          end: "\n\n      return require('" + this.ti.main + "');\n  };\n\n  if (__isAMD) {\n      define([" + (((function() {
            var _ref, _results;
            _ref = this.ti.globalDepsVars;
            _results = [];
            for (globalDep in _ref) {
              globalVars = _ref[globalDep];
              _results.push("'" + globalDep + "'");
            }
            return _results;
          }).call(this)).join(', ')) + "], factory);\n  } else {\n      if (__isNode) {\n          module.exports = factory();\n      } else {\n          factory();\n      }\n  }\n})();"
        };
      }
    }
  });

  AlmondOptimizationTemplates.property({
    paths: {
      get: function() {
        var globalDep, globalVars, nodeOnlyDep, _i, _len, _paths, _ref, _ref1;
        _paths = {};
        _ref = this.ti.globalDepsVars;
        for (globalDep in _ref) {
          globalVars = _ref[globalDep];
          _paths[globalDep] = "getGlobal_" + globalDep;
        }
        _ref1 = this.ti.nodeOnly;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          nodeOnlyDep = _ref1[_i];
          _paths[nodeOnlyDep] = "getNodeOnly_" + nodeOnlyDep;
        }
        return _paths;
      }
    }
  });

  AlmondOptimizationTemplates.property({
    dependencyFiles: {
      get: function() {
        var globalDep, globalVars, nodeOnlyDep, _dependencyFiles, _i, _len, _ref, _ref1;
        _dependencyFiles = {};
        _ref = this.ti.globalDepsVars;
        for (globalDep in _ref) {
          globalVars = _ref[globalDep];
          _dependencyFiles["getGlobal_" + globalDep] = this.grabDependencyVarOrRequireIt(globalDep, globalVars);
        }
        _ref1 = this.ti.nodeOnly;
        for (_i = 0, _len = _ref1.length; _i < _len; _i++) {
          nodeOnlyDep = _ref1[_i];
          _dependencyFiles["getNodeOnly_" + nodeOnlyDep] = this.grabDependencyVarOrRequireIt(nodeOnlyDep, []);
        }
        return _dependencyFiles;
      }
    }
  });

  AlmondOptimizationTemplates.prototype.grabDependencyVarOrRequireIt = function(dep, depVars) {
    var depVar;
    return "define(" + this._function(((function() {
      var _i, _len, _results;
      _results = [];
      for (_i = 0, _len = depVars.length; _i < _len; _i++) {
        depVar = depVars[_i];
        _results.push("if (typeof " + depVar + " !== 'undefined'){return " + depVar + ";}");
      }
      return _results;
    })()).join(';') + ("\nreturn __nodeRequire('" + dep + "');")) + ");";
  };

  return AlmondOptimizationTemplates;

}).call(this, Template);
