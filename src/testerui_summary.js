import React from "react";
import ReactDOM from "react-dom";

import IconButton from '@material-ui/core/IconButton';
import Tooltip from '@material-ui/core/Tooltip';
import Typography from '@material-ui/core/Typography';

import img_cow_ok from './images/cow_ok.png';
import img_cow_err from './images/cow_err.png';
import img_cow_idle from './images/cow_idle.png';


class TesterUISummary extends React.Component {
  constructor(props) {
    super(props);

    this.TESTRESULT_Ok = 0;
    this.TESTRESULT_Error = 1;
    this.TESTRESULT_Idle = 2;

    this.state = {
      astrTestNames: ['a', 'b', 'c', 'd', 'e', 'f', 'g', 'h'],
      atTestStati: [0, 1, 2, 0, 1, 2, 0, 1],
      uiIconSize: 32
    };

    let astrImages = {
      0: img_cow_ok,
      1: img_cow_err,
      2: img_cow_idle
    };
    this.astrImages = astrImages;
  }

  handleCowClick = (uiIndex) => {
    this.props.handleCowClick(uiIndex);
  }

  render() {
    let atCows = []
    this.state.astrTestNames.forEach(function(strName, uiIndex) {
      const tResult = this.state.atTestStati[uiIndex];
      let strImg = this.astrImages[tResult];
      atCows.push(
        <div key={uiIndex} className="TesterUISummary_Cow" id="cow_{uiIndex}">
          <Tooltip title={strName} placement="bottom">
            <IconButton onClick={() => this.handleCowClick(uiIndex)}>
              <img src={strImg} />
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
