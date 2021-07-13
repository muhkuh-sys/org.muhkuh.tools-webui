module.exports = (options, loaderContext) => {
  let strVersion = 'unknown';

  const parser = require('fast-xml-parser');
  const fs = require('fs');

  try {
    const strPackageXml = fs.readFileSync('muhkuh_webui.xml', 'utf8')

    const tPackageJson = parser.parse(strPackageXml, { ignoreAttributes: false });
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
