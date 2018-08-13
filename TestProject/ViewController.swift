//
//  ViewController.swift
//  TestProject
//
//  Created by yasir on 07/08/2018.
//  Copyright © 2018 Vizteck. All rights reserved.
//

import UIKit

class ViewController: UIViewController, UIViewControllerTransitioningDelegate {

    override func viewDidLoad() {
        super.viewDidLoad()
    }

    @IBAction func presentSecondVCButtonTapped(_ sender: Any) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let secondVc = storyBoard.instantiateViewController(withIdentifier: "SecondViewControllerId") as! SecondViewController
        secondVc.transitioningDelegate = self
        secondVc.modalPresentationStyle = .currentContext
        self.present(secondVc, animated: true, completion: nil)
    }

    func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
        let animator = StarWarsGLAnimator()
        animator.duration = 2
        animator.spriteWidth = 5
        return animator
    }

     // MARK: - Navigation

     // In a storyboard-based application, you will often want to do a little preparation before navigation
     override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        let destination = segue.destination
        destination.transitioningDelegate = self
     }
}

