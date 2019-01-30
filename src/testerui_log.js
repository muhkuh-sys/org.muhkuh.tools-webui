import React from "react";
import ReactDOM from "react-dom";


class TesterUILog extends React.Component {
  constructor(props) {
    super(props);

    this.tList = React.createRef();
    this.tListInner = React.createRef();

    /* The buffer border is the part of the buffer lines which are not visible. */
    this.uiBufferBorder = 2;

    this.uiBufferOldTopLine = null;
    this.uiBufferOldBottomLine = null;

    this.state = {
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
      const uiNumberOfLogLines = this.props.auiLogColors.length;
      if( uiNumberOfLogLines==0 ) {
        tListInner.style.backgroundImage = null;
        tListInner.style.backgroundPositionY = null;
      } else {
        /* Get the height of one log line. */
        const uiLineHeightPx = Math.ceil(iScrollHeight / uiNumberOfLogLines);
//        const uiLineHeightPx = this.uiLineHeightPx;

        /* Get the number of buffer lines.
         * This depends on the window size.
         */
        const uiBufferLines = Math.floor(window.innerHeight / uiLineHeightPx);

        /* Get the number of invisible buffer lines. */
        const uiBufferBorder = this.uiBufferBorder;

        /* Get the top and bottom visible lines. */
        const visible_top = Math.floor((iScrollTop + iClientTop) / uiLineHeightPx);
        const visible_bottom = Math.floor((iScrollTop + iClientTop + iClientHeight - 1) / uiLineHeightPx);
//      console.log(iScrollHeight, uiNumberOfLogLines, uiLineHeightPx, visible_top, visible_bottom);

        let uiBufferNewTopLine = null;
        let uiBufferNewBottomLine = null;

        /* Is the visible area at the start of the log? */
        if( visible_bottom < (uiBufferLines-uiBufferBorder) ) {
//        console.log("a");
          uiBufferNewTopLine = 0;
          uiBufferNewBottomLine = Math.min(uiBufferLines, uiNumberOfLogLines);
        }
        else if( visible_top > (uiNumberOfLogLines-uiBufferLines+uiBufferBorder) ) {
//        console.log("b");
          uiBufferNewBottomLine = uiNumberOfLogLines - 1;
          uiBufferNewTopLine = Math.max(uiNumberOfLogLines-uiBufferLines, 0);
        }
        else if( this.uiBufferOldTopLine!==null && this.uiBufferOldBottomLine!==null && visible_top>=(this.uiBufferOldTopLine+uiBufferBorder) && visible_bottom<=(this.uiBufferOldBottomLine-uiBufferBorder)) {
//        console.log("c");
          uiBufferNewTopLine = this.uiBufferOldTopLine;
          uiBufferNewBottomLine = this.uiBufferOldBottomLine;
        }
        else {
//        console.log("d");
          let d = Math.floor((uiBufferLines - (visible_bottom - visible_top)) / 2);
          uiBufferNewTopLine = Math.max(visible_top-d, 0);
          uiBufferNewBottomLine = Math.min(uiBufferNewTopLine+uiBufferLines, uiNumberOfLogLines);
        }

//      console.log(uiBufferNewTopLine, uiBufferNewBottomLine);

        /* Did something change? */
        if( (uiBufferNewTopLine!==this.uiBufferOldTopLine) || (uiBufferNewBottomLine!==this.uiBufferOldBottomLine) ) {
          let aSvg = ["url(\"data:image/svg+xml;utf8,<svg%20xmlns='http://www.w3.org/2000/svg'%20width='"+String(window.innerWidth)+"'%20height='"+String(uiBufferLines*uiLineHeightPx)+"'>"];
          const strFixed = "<rect%20x='0'%20width='"+String(window.innerWidth)+"'%20height='"+String(uiLineHeightPx)+"'%20";
          const astrLogColors = this.props.astrLogColors;
          const auiLogColors = this.props.auiLogColors;
          for(let uiCnt=uiBufferNewTopLine; uiCnt<=uiBufferNewBottomLine; ++uiCnt) {
            const strColor = astrLogColors[auiLogColors[uiCnt]];
            aSvg.push(strFixed + "y='"+String((uiCnt-uiBufferNewTopLine)*uiLineHeightPx)+"'%20style='fill:%23"+strColor+"'/>");
          }
          aSvg.push("</svg>\")");

          const strSvg = aSvg.join('');
          const strPosY = String(uiBufferNewTopLine*uiLineHeightPx)+'px';

          tListInner.style.backgroundImage = strSvg;
          tListInner.style.backgroundPositionY = strPosY;

          this.uiBufferOldTopLine = uiBufferNewTopLine;
          this.uiBufferOldBottomLine = uiBufferNewBottomLine;
        }
      }
    }
  }


  handleScrollThis = () => {
    this.handleScroll();
  }


  componentDidMount() {
    window.addEventListener("resize", this.handleScrollThis);
    this.handleScroll();
  }


  componentDidUpdate() {
    this.handleScroll();
  }


  componentWillUnmount() {
    window.removeEventListener("resize", this.handleScrollThis);
  }


  render() {
    return (
      <div className='TesterLog' ref={this.tList}>
        <div className='TesterLogIn' ref={this.tListInner}>{this.props.strLogLines}</div>
      </div>
    );
  }
}

export default TesterUILog
