import React from "react";
import ReactDOM from "react-dom";

import Typography from '@material-ui/core/Typography';

class TesterUIHeader extends React.Component {
  constructor(props) {
    super(props);
  }

  render() {
    let strTitleColor = 'default';
    let strTitleText = this.props.strTitle;
    if( strTitleText===null ) {
      strTitleColor = 'error';
      strTitleText = 'No title';
    }

    let strSubtitleText = this.props.strSubtitle;
    if( strSubtitleText===null ) {
      strSubtitleText = '-';
    }

    let strCurrentSerial = 'This test uses no serial numbers.';
    if( this.props.fHasSerial==true ) {
      let uiSerial = this.props.uiCurrentSerial;
      if( Number.isInteger(uiSerial)===true ) {
        strCurrentSerial = 'Current serial: ' + String(uiSerial);
      } else {
        strCurrentSerial = 'Current serial: none';
      }
    }

    return (
      <div>
        <Typography align="center" color={strTitleColor} variant="h4" gutterBottom>{strTitleText}</Typography>
        <Typography align="center" variant="subtitle1" gutterBottom>{strSubtitleText}</Typography>
        <Typography variant="h4" gutterBottom>{strCurrentSerial}</Typography>
      </div>
    );
  }
}

export default TesterUIHeader
