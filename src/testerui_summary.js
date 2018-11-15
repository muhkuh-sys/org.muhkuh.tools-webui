import React from "react";
import ReactDOM from "react-dom";

import CircularProgress from '@material-ui/core/CircularProgress';
import IconButton from '@material-ui/core/IconButton';
import Tooltip from '@material-ui/core/Tooltip';
import Typography from '@material-ui/core/Typography';

import ImgCowOk from './images/muhkuh_test_ok.svg';
import ImgCowErr from './images/muhkuh_test_failed.svg';
import ImgCowIdle from './images/muhkuh_untested.svg';


class TesterUISummary extends React.Component {
  constructor(props) {
    super(props);

    this.TESTRESULT_Ok = 0;
    this.TESTRESULT_Error = 1;
    this.TESTRESULT_Idle = 2;

    this.state = {
      astrTestNames: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
      atTestStati: [0, 1, 2, 0, 1, 2, 0, 1]
    };

    let astrImages = {
      0: ImgCowOk,
      1: ImgCowErr,
      2: ImgCowIdle
    };
    this.astrImages = astrImages;
  }

  handleCowClick = (uiIndex) => {
    this.props.handleCowClick(uiIndex);
  }

  render() {
    let atCows = []
    const uiRunningTest = this.props.uiRunningTest;
    this.state.astrTestNames.forEach(function(strName, uiIndex) {
      const tResult = this.state.atTestStati[uiIndex];
      const strImg = this.astrImages[tResult];

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

    let strSerial = 'No current serial.';
    if( this.props.fHasSerial==true ) {
      let uiSerial = this.props.uiCurrentSerial;
      if( Number.isInteger(uiSerial)===true ) {
        strSerial = 'Current serial: ' + String(uiSerial);
      } else {
        strSerial = 'Current serial: none';
      }
    }

    return (
      <div>
        <Typography variant="h4" gutterBottom>{strSerial}</Typography>
        <div className='TesterUISummary_CowBar' style={{backgroundColor: this.props.theme.palette.background.paper}}>
          {atCows}
        </div>
      </div>
    );
  }
}

export default TesterUISummary
