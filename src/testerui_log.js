import React from "react";
import ReactDOM from "react-dom";


class TesterUILog extends React.Component {
  constructor(props) {
    super(props);

    this.tThisRef = React.createRef();

    this.state = {
    };
  }


  componentDidMount() {
    const tThis = this.tThisRef.current;
    if( tThis!==null ) {
      const tParent = tThis.parentNode;
      tParent.scrollTop = this.props.uiInitialScrollPosition;
    }
  }


  append(strLines) {
    const tThis = this.tThisRef.current;
    if( tThis!==null ) {
      /* Get the current scroll position from the parent element.
       * See here for details: https://javascript.info/size-and-scroll
       */
      const tTabContents = tThis.parentNode;
      const iScrollTop = tTabContents.scrollTop;
      const iClientTop = tTabContents.clientTop
      const iClientHeight = tTabContents.clientHeight;
      const iLogHeight = tThis.clientHeight;
//      console.log(iScrollTop, iClientTop, iClientHeight, iLogHeight);
      const iVisibleBottom = iScrollTop + iClientTop + iClientHeight;

      let strLog = tThis.textContent + strLines;
      tThis.textContent = strLog;

      if( iVisibleBottom >= iLogHeight ) {
//        console.log('Bottom visible');

        /* Get the new log height. */
        const iNewLogHeight = tThis.clientHeight;
        /* Is the new bottom line still visible? */
        if( iVisibleBottom < iNewLogHeight ) {
          const iNewScrollTop = iNewLogHeight - iClientHeight;
//          console.log('New Bottom not visible -> scroll to ' + String(iNewScrollTop));
          /* Set the new scroll top. */
          tTabContents.scrollTop = iNewScrollTop;
        }
      }
    }
  }


  render() {
    return (
      <div ref={this.tThisRef} className='TesterLog'>{this.props.strLogLines}</div>
    );
  }
}

export default TesterUILog
