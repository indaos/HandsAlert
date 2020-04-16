
import Foundation

typealias MotionData = (x: Double,y: Double ,z: Double,rx: Double,ry: Double,rz: Double)

class AccTupleBuffer {
    var buffer=[MotionData]()
    var size = 0

    init(size: Int) {
        self.size = size
        self.buffer = []
    }
    
    func addSample(_ sample: (x: Double,y: Double ,z: Double,rx: Double,ry: Double,rz: Double) ) {
        buffer.append(sample)
    }
    
    func reset() {
        buffer=[]
    }
    
    func isFull() -> Bool {
        return size == buffer.count
    }
}



