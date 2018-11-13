import React from "react";
import ReactDOM from "react-dom";

import Typography from '@material-ui/core/Typography';

class TesterUIHeader extends React.Component {
  constructor(props) {
    super(props);

    let _uiFirstSerial = null;
    if( props.uiFirstSerial!==null ) {
      _uiFirstSerial = Number(props.uiFirstSerial);
      if( isNaN(_uiFirstSerial)===true ) {
        _uiFirstSerial = null;
      }
    }
    let _uiLastSerial = null;
    if( props.uiLastSerial!==null ) {
      _uiLastSerial = Number(props.uiLastSerial);
      if( isNaN(_uiLastSerial)===true ) {
        _uiLastSerial = null;
      }
    }
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

    let strSerial = 'This test uses no serial numbers.';
    if( this.props.fHasSerial===true ) {
      let uiFirstSerial = this.props.uiFirstSerial;
      let uiLastSerial = this.props.uiLastSerial;
      if( uiFirstSerial!==null && uiLastSerial!==null )
      {
        strSerial = 'First serial: ' + String(uiFirstSerial) + ', last serial: ' + String(uiLastSerial);
      } else {
        strSerial = 'Serial numbers are not set yet.';
      }
    }

    return (
      <div>
        <Typography align="center" color={strTitleColor} variant="h4" gutterBottom>{strTitleText}</Typography>
        <Typography align="center" variant="subtitle1" gutterBottom>{strSubtitleText}</Typography>
        <Typography variant="body1" gutterBottom>{strSerial}</Typography>
      </div>
    );
  }
}

export default TesterUIHeader
