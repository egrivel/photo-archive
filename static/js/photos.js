/*
 * Javascript functions for photo system
 */

function doWindow(target, id, attrib) {
  var newWindow = window.open(target, id, attrib);
  newWindow.focus();
}

window.onload = () => {
  const swipable = document.getElementById("swipable");
  if (swipable) {
    let startX = 0;
    let startY = 0;

    swipable.addEventListener(
      "touchstart",
      (event) => {
        startX = event.changedTouches[0].screenX;
        startY = event.changedTouches[0].screenY;
      },
      false
    );
    swipable.addEventListener(
      "touchend",
      (event) => {
        const endX = event.changedTouches[0].screenX;
        const endY = event.changedTouches[0].screenY;

        const diffX = endX - startX;
        const diffY = endY - startY;

        if (Math.abs(diffX) > 2 * Math.abs(diffY) && Math.abs(diffX) > 30) {
          if (endX > startX) {
            const prevLink = document.getElementById("prevlink");
            const url = prevLink?.children?.[0]?.href;
            if (url) {
              document.location = url;
            }
          } else {
            const nextLink = document.getElementById("nextlink");
            const url = nextLink?.children?.[0]?.href;
            if (url) {
              document.location = url;
            }
          }
        }
      },
      false
    );
  }
};
