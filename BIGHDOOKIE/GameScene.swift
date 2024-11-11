import SpriteKit

class GameScene: SKScene {
    override func didMove(to view: SKView) {
        // Set up your scene here
        backgroundColor = .black
    }

    // Example function to add nodes or set up the scene
    func setupScene() {
        let label = SKLabelNode(text: "Welcome to GameScene!")
        label.position = CGPoint(x: size.width / 2, y: size.height / 2)
        addChild(label)
    }
}
