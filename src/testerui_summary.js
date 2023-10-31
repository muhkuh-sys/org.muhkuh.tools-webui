import React from 'react';

import CircularProgress from '@mui/material/CircularProgress';
import IconButton from '@mui/material/IconButton';
import Tooltip from '@mui/material/Tooltip';

import ImgCowOk from './images/muhkuh_test_ok.svg';
import ImgCowErr from './images/muhkuh_test_failed.svg';
import ImgCowIdle from './images/muhkuh_untested.svg';
import ImgCowDisabled from './images/muhkuh_disabled.svg';
import ImgCowExcluded from './images/muhkuh_excluded.svg';


class TesterUISummary extends React.Component {
  constructor(props) {
    super(props);

    this.state = {};

    let astrImages = {
      ok: ImgCowOk,
      error: ImgCowErr,
      idle: ImgCowIdle,
      disabled: ImgCowDisabled,
      excluded: ImgCowExcluded
    };
    this.astrImages = astrImages;
  }

  handleCowClick = (uiIndex) => {
    this.props.handleCowClick(uiIndex);
  }

  render() {
    console.log('Here');
    let atCows = []
    const uiRunningTest = this.props.uiRunningTest;
    this.props.astrTestNames.forEach(function(strName, uiIndex) {
      const strState = this.props.atTestStati[uiIndex];
      const strImg = this.astrImages[strState];

      let tProgress = null;
      /* Is this the running test? */
      if( uiIndex==uiRunningTest ) {
        tProgress = (
          <CircularProgress size={this.props.strIconSize} className='TesterUISummary_Progress' />
        );
      }

      atCows.push(
        <div key={uiIndex} className="TesterUISummary_Cow" id="cow_{uiIndex}">
          <Tooltip title={strName} placement="bottom">
            <IconButton onClick={() => this.handleCowClick(uiIndex)} style={{position: 'relative'}}>
              <img src={strImg} style={{height: this.props.strIconSize, width: this.props.strIconSize}}/>
              {tProgress}
            </IconButton>
          </Tooltip>
        </div>
      );
    }, this);

    return (
      <div>
        <div className='TesterUISummary_CowBar' style={{backgroundColor: this.props.theme.palette.background.paper}}>
          {atCows}
        </div>
      </div>
    );
  }
}

export default TesterUISummary
