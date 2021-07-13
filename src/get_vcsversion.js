module.exports = (options, loaderContext) => {
  let strVcsVersion = 'unknown';

  try {
    const git = require('git-rev-sync');

    /* Get a 12 digit commit ID. */
    const strCommitId = git.long().substring(0, 12);
    const fIsDirty = git.isDirty();
    const fIsOnTag = (git.isTagDirty()==false);
    const strTag = git.tag(true);

    let strDirty = '';
    if( fIsDirty==true ) {
      strDirty = '+';
    }

    if( fIsOnTag==true ) {
      strVcsVersion = 'GIT' + strTag + strDirty;
    } else {
      strVcsVersion = 'GIT' + strCommitId + strDirty;
    }
  } catch (err) {
    console.error('Failed to get the VCS version: ' + err);
  }

  console.log('*** get_vcsversion = ' + strVcsVersion + ' ***');
  return { code: "module.exports = '" + strVcsVersion + "';" };
};
