
import Foundation

typealias MotionData = (x: Double,y: Double ,z: Double,rx: Double,ry: Double,rz: Double)

class AccTupleBuffer {
    var buffer=[MotionData]()
    var size = 0

    init(size: Int) {
        self.size = size
        self.buffer = [MotionData](repeating: (0,0,0,0,0,0), count: self.size)
    }
    
    func addSample(_ sample: (x: Double,y: Double ,z: Double,rx: Double,ry: Double,rz: Double) ) {
        buffer.insert(sample, at:0)
        if buffer.count > size {
            buffer.removeLast()
        }
    }
    
    func reset() {
        buffer.removeAll(keepingCapacity: true)
    }
    
    func isFull() -> Bool {
        return size == buffer.count
    }
    

}



