import React from "react";
import ReactDOM from "react-dom";


class TesterUILog extends React.Component {
  constructor(props) {
    super(props);

    let _astrLines = [];
    /* Create a bunch of demo messages. */
    for(let iCnt=1; iCnt<10000; ++iCnt) {
      _astrLines.push('Line ' + String(iCnt));
    }

    this.tList = React.createRef();
    this.tMeasure = React.createRef();

    this.state = {
      astrLines: _astrLines
    };
  }

  handleScroll(iScrollTop, iClientTop, iClientHeight, iOffsetHeight, iScrollHeight) {
    console.log('scroll');

    /* See here for details: https://javascript.info/size-and-scroll */
    const tList = this.tList.current;
    const tMeasure = this.tMeasure.current;
    if( tList!==null && tMeasure!==null ) {
      console.log(iScrollTop, iClientTop, iClientHeight, iOffsetHeight, iScrollHeight);
      console.log(tMeasure.clientHeight);
    }
  }

  render() {
    return (
      <div className='TesterLog' ref={this.tList} style={{height: '10000px'}}>
        <div style={{visibility: 'hidden', position: 'absolute', top: '0px'}} ref={this.tMeasure}>M</div>
        <div>dummy</div>
      </div>
    );
  }
}

export default TesterUILog
