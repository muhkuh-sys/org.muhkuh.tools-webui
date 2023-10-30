module.exports = (options, loaderContext) => {
  let strVersion = 'unknown';

  const fs = require('fs');

  try {
    const strPackageXml = fs.readFileSync('muhkuh_webui.xml', 'utf8')

    const fxparser = require('fast-xml-parser');
    const parser = new fxparser.XMLParser({ ignoreAttributes: false });
    const tPackageJson = parser.parse(strPackageXml);
    if( 'jonchki-artifact' in tPackageJson ) {
      const tJonchkiArtifact = tPackageJson['jonchki-artifact'];
      if( 'info' in tJonchkiArtifact ) {
        const tInfo = tJonchkiArtifact['info'];
        if( '@_version' in tInfo ) {
          strVersion = tInfo['@_version'];
        }
      }
    }
  } catch (err) {
    console.error('Failed to read the package file: ' + err)
  }

  console.log('*** get_version = ' + strVersion + ' ***');
  return { code: "module.exports = '" + strVersion + "';" };
};
