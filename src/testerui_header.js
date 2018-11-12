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
    let strColor = 'default';
    let strText = this.props.strTitle;
    if( strText===null ) {
      strColor = 'error';
      strText = 'No title';
    }
    var tTitle = (
      <Typography align="center" color={strColor} variant="h4" gutterBottom>{strText}</Typography>
    );

    var tSubtitle = null;
    strText = this.props.strSubtitle;
    if( strText!==null ) {
      tSubtitle = (
        <Typography align="center" variant="subtitle1" gutterBottom>{strText}</Typography>
      );
    }

    var tSerial = null;
    if( this.props.fHasSerial===true ) {
      var uiFirstSerial = this.props.uiFirstSerial;
      var uiLastSerial = this.props.uiLastSerial;
      if( uiFirstSerial!==null && uiLastSerial!==null )
      {
        tSerial = (
          <Typography variant="body1" gutterBottom>First serial: {uiFirstSerial}, last serial: {uiLastSerial}</Typography>
        );
      } else {
        tSerial = (
          <Typography variant="body1" gutterBottom>Serial numbers are not set yet.</Typography>
        );
      }
    }

    return (
      <div>
        {tTitle}
        {tSubtitle}
        {tSerial}
      </div>
    );
  }
}

export default TesterUIHeader
