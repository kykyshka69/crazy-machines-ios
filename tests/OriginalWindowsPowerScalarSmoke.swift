import Foundation

@main
struct OriginalWindowsPowerScalarSmoke {
    static func main() {
        typealias W = CMOriginalWindowsPowerScalar
        precondition(W.batterySource == 10)
        precondition(W.transfer(10, blocked: false) == 10)
        precondition(W.transfer(-5, blocked: false) == -5)
        precondition(W.transfer(10, blocked: true) == 0)
        precondition(W.transfer(.nan, blocked: false) == nil)
        precondition(W.motorRotorCommand(from: 10) == -10)
        precondition(W.motorRotorCommand(from: -10) == 10)
        precondition(W.motorRotorCommand(from: .infinity) == nil)
        precondition(W.motorTriggersGoal(power: 10))
        precondition(W.motorTriggersGoal(power: -10))
        precondition(!W.motorTriggersGoal(power: 0.5))
        precondition(!W.motorTriggersGoal(power: -0.5))
        precondition(!W.motorTriggersGoal(power: .nan))
        precondition(W.lampTriggersGoal(power: 10))
        precondition(!W.lampTriggersGoal(power: 3))
        precondition(!W.lampTriggersGoal(power: -10))
        precondition(!W.lampTriggersGoal(power: .infinity))
        precondition(W.lightningTriggersGoal(power: 10))
        precondition(!W.lightningTriggersGoal(power: 1))
        precondition(!W.lightningTriggersGoal(power: -10))
        precondition(W.lampVisualFactor(power: 10) == 1)
        precondition(W.lampVisualFactor(power: 5) == 0.5)
        precondition(W.lampVisualFactor(power: -10) == -1)
        precondition(W.lampVisualFactor(power: .nan) == nil)
        print("Authentic Win32 power propagation, motor polarity, lamp and lightning activation thresholds: passed")
    }
}