import UIKit

class MyViewController: UIViewController {
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Customize your view controller's view and add subviews here
        
        // Example: Add a label to the view
        print("SADASDASDSADASDASSDASDASDASDASDASASDASDASD")
        let label = UILabel()
        label.text = "Hello, World!"
        print("ASDASD")
        label.textAlignment = .center
        label.frame = CGRect(x: 0, y: 0, width: 200, height: 50)
        label.center = view.center
        view.addSubview(label)
    }
}
