import React from "react";
import ReactDOM from "react-dom";


class TesterUILog extends React.Component {
  constructor(props) {
    super(props);

    let _astrLines = [];
    /* Create a bunch of demo messages. */
    for(let iCnt=0; iCnt<10000; ++iCnt) {
      _astrLines.push('Line ' + String(iCnt));
    }

    this.tList = React.createRef();
    this.tListInner = React.createRef();

    /* Get the inner height of the window as a hint how many rows should be bufferd. */
    this.iWindowHeight = window.innerHeight;

    /* The buffer border is the part of the buffer lines which are not visible. */
    this.uiBufferBorder = 2;
    /* TODO: The number of buffer lines should be derived from the window size. For a quick test it is fixed. */
    this.uiBufferLines = 16;

/*
    this.uiBufferLines = Math.ceil(this.iWindowHeight / _iLineSize);
    this.uiBufferBottom = this.uiBufferLines;
*/

    this.astrColors = [
      'ff0000',
      '00ff00',
      '0000ff',
      'ffff00'
    ];

    this.uiBufferOldTopLine = null;
    this.uiBufferOldBottomLine = null;

    this.state = {
      astrLines: _astrLines,
      uiNumberOfLogLines: _astrLines.length
    };
  }


  handleScroll() {
//    console.log('--- scroll ---');

    const tList = this.tList.current;
    const tListInner = this.tListInner.current;
    if( tList!==null && tListInner!==null ) {
      /* Get the scroll position from the parent node.
       * See here for details: https://javascript.info/size-and-scroll
       */
      const tTabContents = tList.parentNode;
      const iScrollTop = tTabContents.scrollTop;
      const iClientTop = tTabContents.clientTop
      const iClientHeight = tTabContents.clientHeight;
      const iScrollHeight = tTabContents.scrollHeight;
//      console.log(iScrollTop, iClientTop, iClientHeight, iScrollHeight);

      /* Get the number of log lines. */
      const uiNumberOfLogLines = this.state.uiNumberOfLogLines;

      /* Get the height of one log line. */
      const uiLineHeightPx = Math.ceil(iScrollHeight / uiNumberOfLogLines);

      /* Get the top and bottom visible lines. */
      const visible_top = Math.floor((iScrollTop + iClientTop) / uiLineHeightPx);
      const visible_bottom = Math.floor((iScrollTop + iClientTop + iClientHeight - 1) / uiLineHeightPx);
//      console.log(iScrollHeight, uiNumberOfLogLines, uiLineHeightPx, visible_top, visible_bottom);

      let uiBufferNewTopLine = null;
      let uiBufferNewBottomLine = null;

      /* Is the visible area at the start of the log? */
      if( visible_bottom < (this.uiBufferLines-this.uiBufferBorder) ) {
//        console.log("a");
        uiBufferNewTopLine = 0;
        uiBufferNewBottomLine = Math.min(this.uiBufferLines, uiNumberOfLogLines);
      }
      else if( visible_top > (uiNumberOfLogLines-this.uiBufferLines+this.uiBufferBorder) ) {
//        console.log("b");
        uiBufferNewBottomLine = uiNumberOfLogLines - 1;
        uiBufferNewTopLine = Math.max(uiNumberOfLogLines-this.uiBufferLines, 0);
      }
      else if( this.uiBufferOldTopLine!==null && this.uiBufferOldBottomLine!==null && visible_top>=(this.uiBufferOldTopLine+this.uiBufferBorder) && visible_bottom<=(this.uiBufferOldBottomLine-this.uiBufferBorder)) {
//        console.log("c");
        uiBufferNewTopLine = this.uiBufferOldTopLine;
        uiBufferNewBottomLine = this.uiBufferOldBottomLine;
      }
      else {
//        console.log("d");
        let d = Math.floor((this.uiBufferLines - (visible_bottom - visible_top)) / 2);
        uiBufferNewTopLine = Math.max(visible_top-d, 0);
        uiBufferNewBottomLine = Math.min(uiBufferNewTopLine+this.uiBufferLines, uiNumberOfLogLines);
      }

//      console.log(uiBufferNewTopLine, uiBufferNewBottomLine);

      /* Did something change? */
      if( (uiBufferNewTopLine!==this.uiBufferOldTopLine) || (uiBufferNewBottomLine!==this.uiBufferOldBottomLine) ) {
        let aSvg = ["url(\"data:image/svg+xml;utf8,<svg%20xmlns='http://www.w3.org/2000/svg'%20width='"+String(window.innerWidth)+"'%20height='"+String(this.uiBufferLines*uiLineHeightPx)+"'>"];
        const strFixed = "<rect%20x='0'%20width='"+String(window.innerWidth)+"'%20height='"+String(uiLineHeightPx)+"'%20";
        for(let uiCnt=uiBufferNewTopLine; uiCnt<=uiBufferNewBottomLine; ++uiCnt) {
          /* TODO: this is just a demo. Take this from an array. */
          const strColor = this.astrColors[uiCnt&3];
          /* TODO: Set the width to 100%? */
          aSvg.push(strFixed + "y='"+String((uiCnt-uiBufferNewTopLine)*uiLineHeightPx)+"'%20style='fill:%23"+strColor+"'/>");
        }
        aSvg.push("</svg>\")");

        const strSvg = aSvg.join('');
        const strPosY = String(uiBufferNewTopLine*uiLineHeightPx)+'px';

        tListInner.style.backgroundImage = strSvg;
        tListInner.style.backgroundPositionY = strPosY;
      }

      this.uiBufferOldTopLine = uiBufferNewTopLine;
      this.uiBufferOldBottomLine = uiBufferNewBottomLine;
    }
  }


  render() {
    return (
      <div className='TesterLog' ref={this.tList}>
        <div className='TesterLogIn' ref={this.tListInner}>{this.state.astrLines.join('\n')}</div>
      </div>
    );
  }
}

export default TesterUILog
