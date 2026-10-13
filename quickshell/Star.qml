import QtQuick
import QtQuick.Shapes

// Fünfzackiger Stern als Vektor – scharf bei jeder Skalierung
Item {
    id: star
    property real size: 10
    property color color: Theme.accent
    property real inner: 0.42          // Verhältnis Innen-/Außenradius

    implicitWidth: size
    implicitHeight: size

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer

        ShapePath {
            strokeWidth: -1
            fillColor: star.color
            PathPolyline {
                path: {
                    const pts = []
                    const cx = star.size / 2, cy = star.size / 2 + star.size * 0.04
                    const R = star.size / 2, r = R * star.inner
                    for (let i = 0; i <= 10; i++) {
                        const a = -Math.PI / 2 + i * Math.PI / 5
                        const rad = i % 2 === 0 ? R : r
                        pts.push(Qt.point(cx + rad * Math.cos(a), cy + rad * Math.sin(a)))
                    }
                    return pts
                }
            }
        }
    }
}
