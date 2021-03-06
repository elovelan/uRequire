// Generated by CoffeeScript 1.6.3
var BundleBuilder, UError, blendConfigs, fs, l, uRequireConfigMasterDefaults, upath, _, _B,
  __indexOf = [].indexOf || function(item) { for (var i = 0, l = this.length; i < l; i++) { if (i in this && this[i] === item) return i; } return -1; };

_ = require('lodash');

_ = require('lodash');

fs = require('fs');

_B = require('uberscore');

l = new _B.Logger('urequire/BundleBuilder');

upath = require('../paths/upath');

uRequireConfigMasterDefaults = require('../config/uRequireConfigMasterDefaults');

blendConfigs = require('../config/blendConfigs');

UError = require('../utils/UError');

/*
  Load config :
    * check options
    * Load (a) bundle(s) and (a) build(s)
    * Build & watch for changes
*/


BundleBuilder = (function() {
  function BundleBuilder(configs, deriveLoader) {
    var err, finalCfg, uerr;
    this.configs = configs;
    configs.push(uRequireConfigMasterDefaults);
    finalCfg = blendConfigs(configs, deriveLoader);
    _.defaults(finalCfg.bundle, {
      filez: ['**/*.*']
    });
    this.bundleCfg = finalCfg.bundle;
    this.buildCfg = finalCfg.build;
    if (this.buildCfg.debugLevel != null) {
      _B.Logger.setDebugLevel(this.buildCfg.debugLevel, 'urequire');
      l.debug(0, "Setting userCfg _B.Logger.setDebugLevel(" + this.buildCfg.debugLevel + ", 'urequire')");
    }
    if (!this.buildCfg.verbose) {
      if (this.buildCfg.debugLevel >= 50) {
        l.warn('Enabling verbose, because debugLevel >= 50');
      } else {
        _B.Logger.prototype.verbose = function() {};
      }
    }
    l.verbose('uRequire v' + l.VERSION + ' initializing...');
    if (l.deb(40)) {
      l.debug(40, "user config follows (NOTE: duplicate debug/warnings will follow!)");
      l.debug(40, blendConfigs(configs.slice(0, +(configs.length - 2) + 1 || 9e9), deriveLoader));
    }
    if (l.deb(20)) {
      l.debug("final config :\n", finalCfg);
    }
    /* Lets check & fix different formats or quit if we have anomalies*/

    this.Bundle = require('./Bundle');
    this.Build = require('./Build');
    if (this.isCheckAndFixPaths() && this.isCheckTemplate()) {
      try {
        this.bundle = new this.Bundle(this.bundleCfg);
        this.build = new this.Build(this.buildCfg);
      } catch (_error) {
        err = _error;
        l.err(uerr = "Generic error while initializing @bundle or @build", err);
        throw new UError(uerr, {
          nested: err
        });
      }
    } else {
      l.err("Something went wrong with paths or template");
      this.buildCfg.done(false);
    }
  }

  BundleBuilder.prototype.buildBundle = function(filenames) {
    if (!(!this.build || !this.bundle)) {
      return this.bundle.buildChangedResources(this.build, filenames);
    } else {
      l.err("buildBundle(): I have !@build or !@bundle - can't build!");
      return this.buildCfg.done(false);
    }
  };

  BundleBuilder.prototype.watch = function() {
    var bundleBuilder, gaze, path, watchDirs, watchFiles;
    bundleBuilder = this;
    watchFiles = [];
    watchDirs = [];
    gaze = require('gaze');
    path = require('path');
    fs = require('fs');
    return gaze(bundleBuilder.bundle.path + '/**/*.*', function(err, watcher) {
      var addDirs, runBuildBundle;
      l.log('Watching started...');
      watcher.on('all', function(event, filepath) {
        var filepathStat;
        if (event !== 'deleted') {
          try {
            filepathStat = fs.statSync(filepath);
          } catch (_error) {
            err = _error;
          }
        }
        filepath = path.relative(process.cwd(), filepath);
        if (filepathStat != null ? filepathStat.isDirectory() : void 0) {
          return l.log("Adding '" + filepath + "' as new watch directory is NOT SUPPORTED yet.");
        } else {
          l.log("Watch file '" + filepath + "' has " + event + ".");
          if (_.isEmpty(watchFiles)) {
            _.delay(runBuildBundle, 500);
          }
          return watchFiles.push(path.relative(bundleBuilder.bundle.path, filepath));
        }
      });
      addDirs = function() {
        var dir, _i, _len;
        for (_i = 0, _len = watchDirs.length; _i < _len; _i++) {
          dir = watchDirs[_i];
          watcher.add(dir);
        }
        return watchDirs = [];
      };
      return runBuildBundle = function() {
        if (!_.isEmpty(watchFiles)) {
          bundleBuilder.buildBundle(watchFiles);
          watchFiles = [];
        } else {
          l.warn('EMPTY watchFiles = ', watchFiles);
        }
        return l.log('Watching again...');
      };
    });
  };

  BundleBuilder.prototype.isCheckTemplate = function() {
    var _ref;
    if (_ref = this.buildCfg.template.name, __indexOf.call(this.Build.templates, _ref) < 0) {
      l.err("Quitting build, invalid template '" + this.buildCfg.template.name + "' specified.\nUse -h for help");
      return false;
    }
    return true;
  };

  BundleBuilder.prototype.isCheckAndFixPaths = function() {
    var cfgFile, dirName, pathsOk, _ref, _ref1, _ref2;
    pathsOk = true;
    if (((_ref = this.bundleCfg) != null ? _ref.path : void 0) == null) {
      if (cfgFile = (_ref1 = this.configs[0]) != null ? (_ref2 = _ref1.derive) != null ? _ref2[0] : void 0 : void 0) {
        if (dirName = upath.dirname(cfgFile)) {
          l.warn("Assuming path = '" + dirName + "' from 1st configFile: '" + cfgFile + "'");
          this.bundleCfg.path = dirName;
        } else {
          l.err("Quitting build, cant assume path from 1st configFile: '" + cfgFile + "'");
          pathsOk = false;
        }
      } else {
        l.err("Quitting build, no path specified.\nUse -h for help");
        pathsOk = false;
      }
    }
    if (pathsOk) {
      if (this.buildCfg.forceOverwriteSources) {
        this.buildCfg.dstPath = this.bundleCfg.path;
        l.verbose("Forced output to '" + this.buildCfg.dstPath + "'");
      } else {
        if (!this.buildCfg.dstPath) {
          l.err("Quitting build, no --dstPath specified.\nUse -f *with caution* to overwrite sources (no need to specify & ignored --dstPath).");
          pathsOk = false;
        } else {
          if (upath.normalize(this.buildCfg.dstPath) === upath.normalize(this.bundleCfg.path)) {
            l.err("Quitting build, dstPath === path.\nUse -f *with caution* to overwrite sources (no need to specify & ignored --dstPath).");
            pathsOk = false;
          }
        }
      }
    }
    return pathsOk;
  };

  return BundleBuilder;

})();

module.exports = BundleBuilder;

/* Debug information*/

