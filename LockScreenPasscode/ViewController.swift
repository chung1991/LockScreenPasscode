//
//  ViewController.swift
//  LockScreenPasscode
//
//  Created by Chung Nguyen on 7/7/22.
//

import UIKit

// feature
// - allow touch and drag to connect
// - maximum connect 9 points
// - UI: show drag visually
// - UI: release touch remove path


struct UserMovement {
    var path: [[Int]] // [0,0] -> [0,1]
    init () {
        path = []
    }
}

struct ScreenLock {
    var lockLocations: [[Bool]] // true/false: already connect/not connected
    init() {
        lockLocations = Array(repeating: Array(repeating: false, count: 3), count: 3)
    }
}

class MovementManager {
    func addTouch(_ r: Int, _ c: Int, _ screen: ScreenLock) -> Bool {
        // return whether or not touch able to connect
        guard !screen.lockLocations[r][c] else {
            return false
        }
        return true
    }
}


protocol ViewModelDelegate: AnyObject {
    func touchIsConnected(_ r: Int, _ c: Int)
    func touchesIsClear()
}

class ViewModel {
    var manager = MovementManager()
    var screen = ScreenLock()
    var userMoves = UserMovement()
    weak var delegate: ViewModelDelegate?
    func checkTouch(_ r: Int, _ c: Int) -> Bool {
        if manager.addTouch(r, c, screen) {
            // mark it touch
            screen.lockLocations[r][c] = true
            // add user moves
            userMoves.path.append([r,c])
            
            // fire delegate
            delegate?.touchIsConnected(r, c)
            return true
        }
        return false
    }
    
    func releaseTouch() {
        screen = ScreenLock()
        userMoves = UserMovement()
        delegate?.touchesIsClear()
    }
}

class CustomLabel: UILabel {
    var r: Int = -1
    var c: Int = -1
    override init(frame: CGRect) {
        super.init(frame: frame)
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

class ViewController: UIViewController {
    
    var viewModel = ViewModel()
    let mainQueue = DispatchQueue.main
    
    lazy var vStack: UIStackView = {
        let stack = UIStackView()
        stack.axis = .vertical
        return stack
    }()
    
    lazy var hStacks: [UIStackView] = {
        var stacks: [UIStackView] = []
        for _ in 0..<3 {
            let stack = UIStackView()
            stack.axis = .horizontal
            stacks.append(stack)
        }
        return stacks
    }()
    
    lazy var cells: [CustomLabel] = {
        var cells: [CustomLabel] = []
        for _ in 0..<9 {
            let cell = CustomLabel()
            cells.append(cell)
        }
        return cells
    }()
    
    // For line drawing
    var prev: CGPoint?
    var lineLayers: [CAShapeLayer] = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        setupViews()
        setupAutolayouts()
        setupDelegates()
    }

    func setupViews() {
        view.backgroundColor = .blue
        view.addSubview(vStack)
        vStack.spacing = 50
        for hStack in hStacks {
            hStack.spacing = 50
            vStack.addArrangedSubview(hStack)
        }
        for (i, cell) in cells.enumerated() {
            let r = i / 3
            let c = i % 3
            cell.r = r
            cell.c = c
            cell.layer.borderWidth = 1
            cell.layer.cornerRadius = 25
            cell.layer.masksToBounds = true
            cell.backgroundColor = .systemBackground
            cell.textAlignment = .center
            cell.font = .systemFont(ofSize: 70)
            hStacks[r].addArrangedSubview(cell)
        }
    }
    
    func setupAutolayouts() {
        vStack.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            vStack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            vStack.centerXAnchor.constraint(equalTo: view.centerXAnchor)
        ])
        
        for (_, cell) in cells.enumerated() {
            cell.translatesAutoresizingMaskIntoConstraints = false
            NSLayoutConstraint.activate([
                cell.widthAnchor.constraint(equalToConstant: 50),
                cell.heightAnchor.constraint(equalToConstant: 50)
            ])
        }
        
    }
    
    func setupDelegates() {
        let tapGesture = UIPanGestureRecognizer(target: self,
                                                  action: #selector(hovering(_:)))
        view.gestureRecognizers = [tapGesture]
        view.isUserInteractionEnabled = true
        
        viewModel.delegate = self
    }
    
    func getCell(_ recognizer: UIPanGestureRecognizer) -> CustomLabel? {
        for cell in cells {
            let loc = recognizer.location(in: cell)
            if loc.y >= 0 && loc.y <= cell.frame.height &&
                loc.x >= 0 && loc.x <= cell.frame.width {
                return cell
            }
        }
        return nil
    }
    
    @objc func hovering(_ recognizer: UIPanGestureRecognizer) {
        switch recognizer.state {
        case .began:
            break
        case .changed:
            if let cell = getCell(recognizer) {
                if viewModel.checkTouch(cell.r, cell.c) {
                    let cur = recognizer.location(in: view)
                    if let prev = self.prev {
                        self.drawLineFromPointToPoint(startX: Int(prev.x),
                                                      toEndingX: Int(cur.x),
                                                      startingY: Int(prev.y),
                                                      toEndingY: Int(cur.y),
                                                      ofColor: .label,
                                                      widthOfLine: 10.0,
                                                      inView: self.view)
                    }
                    self.prev = cur
                }
            }
        case .ended:
            viewModel.releaseTouch()
            
            // reset shape layers when touch ends
            for shapeLayer in lineLayers {
                shapeLayer.removeFromSuperlayer()
            }
            lineLayers = []
            prev = nil
        default:
            break
        }
    }
    
    func drawLineFromPointToPoint(startX: Int, toEndingX endX: Int, startingY startY: Int, toEndingY endY: Int, ofColor lineColor: UIColor, widthOfLine lineWidth: CGFloat, inView view: UIView) {

        let path = UIBezierPath()
        path.move(to: CGPoint(x: startX, y: startY))
        path.addLine(to: CGPoint(x: endX, y: endY))

        let shapeLayer = CAShapeLayer()
        shapeLayer.path = path.cgPath
        shapeLayer.strokeColor = lineColor.cgColor
        shapeLayer.lineWidth = lineWidth

        lineLayers.append(shapeLayer)
        view.layer.addSublayer(shapeLayer)

    }
}

extension ViewController: ViewModelDelegate {
    func touchIsConnected(_ r: Int, _ c: Int) {
        mainQueue.async { [weak self] in
            guard let self = self else { return }
            let index = r * 3 + c
            self.cells[index].text = "•"
        }
    }
    
    func touchesIsClear() {
        mainQueue.async { [weak self] in
            guard let self = self else { return }
            for cell in self.cells {
                cell.text = ""
            }
        }
    }
}



