pragma ComponentBehavior: Bound
import QtQuick

// Event-driven gradient stroke only: no interior fill, texture sampling or repaint loop.
Canvas {
    id: root
    required property var geometry
    property real strength: 0
    onGeometryChanged: requestPaint()
    onStrengthChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (width < 2 || height < 2 || strength <= 0) return;
        const l=.5, t=.5, r=width-.5, b=height-.5;
        const tl=Math.max(0,geometry.topLeftRadius-.5), tr=Math.max(0,geometry.topRightRadius-.5);
        const bl=Math.max(0,geometry.bottomLeftRadius-.5), br=Math.max(0,geometry.bottomRightRadius-.5);
        ctx.beginPath();ctx.moveTo(l+tl,t);ctx.lineTo(r-tr,t);ctx.quadraticCurveTo(r,t,r,t+tr);
        ctx.lineTo(r,b-br);ctx.quadraticCurveTo(r,b,r-br,b);ctx.lineTo(l+bl,b);
        ctx.quadraticCurveTo(l,b,l,b-bl);ctx.lineTo(l,t+tl);ctx.quadraticCurveTo(l,t,l+tl,t);
        ctx.closePath();
        const gradient=ctx.createLinearGradient(0,0,0,height);
        gradient.addColorStop(0,Qt.rgba(1,1,1,strength*.42));
        gradient.addColorStop(.45,Qt.rgba(1,1,1,strength*.06));
        gradient.addColorStop(1,Qt.rgba(0,0,0,strength*.18));
        ctx.strokeStyle=gradient;ctx.lineWidth=1;ctx.stroke();
    }
}
