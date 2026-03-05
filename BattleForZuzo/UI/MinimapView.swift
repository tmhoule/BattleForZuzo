import SwiftUI

struct MinimapView: View {
    let gameState: GameState
    var onTapLocation: ((CGPoint) -> Void)?

    private let minimapSize: CGFloat = 120

    var body: some View {
        Canvas { context, size in
            guard let map = gameState.map else { return }

            let scaleX = size.width / CGFloat(map.width)
            let scaleY = size.height / CGFloat(map.height)

            let exploredTiles = gameState.humanPlayer?.exploredTiles

            // Draw terrain pixels — black if unexplored
            for col in 0..<map.width {
                for row in 0..<map.height {
                    let coord = HexLayout.offsetToAxial(col: col, row: row)
                    guard let tile = map.tile(at: coord) else { continue }

                    let rect = CGRect(
                        x: CGFloat(col) * scaleX,
                        y: CGFloat(row) * scaleY,
                        width: max(scaleX, 1),
                        height: max(scaleY, 1)
                    )

                    if let explored = exploredTiles, !explored.contains(coord) {
                        context.fill(Path(rect), with: .color(.black))
                    } else {
                        context.fill(Path(rect), with: .color(Color(tile.terrain.color)))
                    }
                }
            }

            // Draw cities as dots (only if explored)
            for city in map.cities.values {
                if let explored = exploredTiles, !explored.contains(city.position) { continue }

                let offset = HexLayout.axialToOffset(q: city.position.q, r: city.position.r)
                let cx = CGFloat(offset.col) * scaleX + scaleX / 2
                let cy = CGFloat(offset.row) * scaleY + scaleY / 2
                let dotSize: CGFloat = 4

                let ownerColor: Color
                if let ownerID = city.ownerID,
                   let player = gameState.players.first(where: { $0.id == ownerID }) {
                    ownerColor = Color(player.color)
                } else {
                    ownerColor = .white
                }

                context.fill(
                    Path(ellipseIn: CGRect(x: cx - dotSize/2, y: cy - dotSize/2, width: dotSize, height: dotSize)),
                    with: .color(ownerColor)
                )
            }

            // Draw unit positions as smaller dots
            if let human = gameState.humanPlayer {
                let visible = gameState.fogOfWarSystem?.visibleHexes(for: human) ?? []
                for unit in gameState.units {
                    guard unit.isAlive && !unit.isLoaded else { continue }
                    guard visible.contains(unit.position) || unit.ownerID == human.id else { continue }

                    let offset = HexLayout.axialToOffset(q: unit.position.q, r: unit.position.r)
                    let ux = CGFloat(offset.col) * scaleX + scaleX / 2
                    let uy = CGFloat(offset.row) * scaleY + scaleY / 2

                    let unitColor: Color
                    if let player = gameState.players.first(where: { $0.id == unit.ownerID }) {
                        unitColor = Color(player.color)
                    } else {
                        unitColor = .white
                    }

                    context.fill(
                        Path(ellipseIn: CGRect(x: ux - 1.5, y: uy - 1.5, width: 3, height: 3)),
                        with: .color(unitColor)
                    )
                }
            }
        }
        .frame(width: minimapSize, height: minimapSize)
        .background(Color.black.opacity(0.7))
        .cornerRadius(6)
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(Color.gray.opacity(0.4), lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture { location in
            guard let map = gameState.map else { return }
            let col = Int(location.x / minimapSize * CGFloat(map.width))
            let row = Int(location.y / minimapSize * CGFloat(map.height))
            let coord = HexLayout.offsetToAxial(col: col, row: row)
            let pixelPos = Constants.hexLayout.hexToPixel(coord)
            onTapLocation?(pixelPos)
        }
    }
}
