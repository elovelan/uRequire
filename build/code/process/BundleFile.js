// Generated by CoffeeScript 1.6.3
var BundleFile, UError, fs, l, upath, _, _B;

_ = require('lodash');

fs = require('fs');

_B = require('uberscore');

l = new _B.Logger('urequire/BundleFile');

upath = require('../paths/upath');

UError = require('../utils/UError');

/*
  A dummy/base class, representing any file in the bundle
*/


BundleFile = (function() {
  Function.prototype.property = function(p) {
    var d, n;
    for (n in p) {
      d = p[n];
      Object.defineProperty(this.prototype, n, d);
    }
    return null;
  };

  /*
    @param {Object} bundle The Bundle where this BundleFile belongs
    @param {String} filename, bundleRelative eg 'models/PersonModel.coffee'
  */


  function BundleFile(bundle, filename) {
    this.bundle = bundle;
    this.filename = filename;
    this.dstFilename = this.srcFilename;
  }

  BundleFile.prototype.refresh = function() {
    var statProps, stats;
    if (!fs.existsSync(this.srcFilepath)) {
      throw new UError("BundleFile missing '" + this.srcFilepath + "'");
    } else {
      stats = _.pick(fs.statSync(this.srcFilepath), statProps = ['mtime', 'size']);
      if (!_.isEqual(stats, this.stats)) {
        this.hasChanged = true;
      } else {
        this.hasChanged = false;
        if (l.deb(90)) {
          l.debug("No changes in " + statProps + " of file '" + this.dstFilename + "' ");
        }
      }
    }
    this.stats = stats;
    return this.hasChanged;
  };

  BundleFile.prototype.reset = function() {
    return delete this.stats;
  };

  BundleFile.property({
    extname: {
      get: function() {
        return upath.extname(this.filename);
      }
    },
    srcFilename: {
      get: function() {
        return this.filename;
      }
    },
    srcFilepath: {
      get: function() {
        return upath.join(this.bundle.path, this.filename);
      }
    },
    dstFilepath: {
      get: function() {
        if (this.bundle.build) {
          return upath.join(this.bundle.build.dstPath, this.dstFilename);
        }
      }
    },
    dstExists: {
      get: function() {
        if (this.dstFilepath) {
          return fs.existsSync(this.dstFilepath);
        }
      }
    }
  });

  return BundleFile;

})();

module.exports = BundleFile;
