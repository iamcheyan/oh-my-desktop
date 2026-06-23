pragma Singleton
import Quickshell

Singleton {
    id: root

    // Pure function: accumulate delta into the provided accumulator and
    // return discrete steps. The caller owns the accumulator (a numeric
    // property on its root item) so state is never shared between components.
    // Returns 0 when not enough delta has accumulated for a full step.
    function getSteps(angleDeltaY, accum) {
        const newVal = accum + angleDeltaY
        if (Math.abs(newVal) >= 120) {
            const steps = Math.trunc(newVal / 120)
            return { steps: steps, accum: newVal - steps * 120 }
        }
        return { steps: 0, accum: newVal }
    }
}