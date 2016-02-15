//
// Created by David Hedbor on 2/13/16.
// Copyright (c) 2016 NeoTron. All rights reserved.
//
// Some functionality especially for Elite: Dangerous to calculcate gravity, core route distances tc.
// Limited functionality outside of E:D :-)

import Foundation
import DiscordAPI

class ScienceMessageHandler : MessageHandler {
    private let densitySigmaArray : [(String,Double,Double,Double,Double)] = [
            ("IW",1.06E+12,1.84E+12,2.62E+12,3.40E+12),
            ("RIW",2.25E+12,2.82E+12,3.38E+12,3.95E+12),
            ("RW",2.94E+12,3.77E+12,4.60E+12,5.43E+12),
            ("HMC",1.21E+12,4.60E+12,8.00E+12,1.14E+13),
            ("MR",1.47E+12,7.99E+12,1.45E+13,2.10E+13),
            ("WW",1.51E+12,4.24E+12,6.97E+12,9.70E+12),
            ("ELW",4.87E+12,5.65E+12,6.43E+12,7.21E+12),
            ("AW",4.23E+11,3.50E+12,6.59E+12,9.67E+12)
    ]

    override var commands: [MessageCommand]? {
        return [
                ("g", "Calculate gravity for a planet. Arguments: <Earth masses> <radius in km>"),
                ("route", "Calculate optimal core routing distance. Arguments: <jump range> <kly to Sgr A*> [optional: max route length in ly]"),
                ("kly/hr", "Calculate max kly travelled per hour. Arguments: <jump range> [optional: time per jump in seconds (default 45s)]")
        ]
    }

    override func handleCommand(command: String, args: [String], message: Message) -> Bool {
        switch(command) {
        case "g":
            handleGravity(args, message: message)
        case "route":
            handleRoute(args, message: message)
        case "kly/hr":
            handleKlyPerHour(args, message: message)
        default:
            return false
        }
        return true
    }

    private func handleKlyPerHour(args: [String], message: Message) {
        if args.count < 1 {
            message.replyToChannel("Missing arguments. Expected: <jump range> [time per jump in seconds]")
            return
        }

        guard let jumpRange = Double(args[0]) else {
            message.replyToChannel("Error: Jump range be a numbers.")
            return
        }

        var jumpTime = 45.0

        if args.count > 1 {
            if let optJumpTime = Double(args[1]) {
                jumpTime = optJumpTime
            }
        }
        let jumpsPerHour = 3600.0 / jumpTime
        let avgJump = jumpRange * 0.97
        let rangePerHour = round(jumpsPerHour * avgJump) // Random
        message.replyToChannel("Spending an average of *\(jumpTime)s* per system, with an average hop of *\(avgJump)* ly, 97% of *\(jumpRange)*, you can travel ** \(rangePerHour) ly / hour**.")
    }

    private func handleGravity(args: [String], message: Message) {
        if args.count < 2 {
            message.replyToChannel("Missing arguments. Expected: <EarthMasses> <Radius in KM>")
            return
        }

        guard let planetMass = Double(args[0]), planetRadius = Double(args[1]) else {
            message.replyToChannel("Error: earth masses and planet radius parameters should be numbers.")
            return
        }

        let G = 6.67*pow(10,-11)
        let earthMass = 5.98*pow(10, 24)
        let earthRadius = 6378000.0
        let baseG = G * earthMass / pow(earthRadius, 2.0)
        let planetG = (G*planetMass*earthMass/pow(planetRadius*1000, 2.0))
        let planetDensity = planetMass*earthMass/(4.0/3.0*M_PI*pow(planetRadius, 3))
        var planetM2Str: String
        var planetGStr : String
        if planetG > 1000 {
            planetM2Str = String(format: "%.2e", planetG)
            planetGStr = String(format: "%.2e", planetG/baseG)
        } else {
            planetM2Str = String(format: "%.2f", planetG)
            planetGStr = String(format: "%.2f", planetG / baseG)
        }
        var maybeTypes = [String]()
        var likelyTypes = [String]()
        for row in densitySigmaArray {
            if planetDensity > row.2 && planetDensity < row.3 {
                likelyTypes.append(row.0)
            } else if planetDensity > row.1 && planetDensity < row.4 {
                maybeTypes.append(row.0)
            }
        }
        var densityString = ""
        if likelyTypes.count > 0 {
            densityString += ". **Likely**: "+likelyTypes.sort().joinWithSeparator(", ")
        }
        if maybeTypes.count > 0 {
            densityString += ". **Possible**: "+maybeTypes.sort().joinWithSeparator(", ")
        }
        let planetDensityStr = String(format: "%.2e", planetDensity)

        message.replyToChannel("The gravity for a planet with \(planetMass) Earth Masses and a radius of \(planetRadius) km is **\(planetM2Str)** m/s^2 or **\(planetGStr)** g. It has a density of **\(planetDensityStr)** kg/km^3\(densityString)")
    }

    private func handleRoute(args: [String], message: Message) {
        let failure = false
        var maxDistance = 1000.0
        if args.count < 2 {
            message.replyToChannel("Missing arguments. Expected: <JumpRange> <SgrA* distance in kly> [optional max plot in ly]")
            return
        }

        guard let jumpRange = Double(args[0]), var distance = Double(args[1]) else {
            message.replyToChannel("Error: jump range and distance parameters should be numbers.")
            return
        }

        if args.count > 2 {
            if let optMaxDistance = Double(args[2]) {
                maxDistance = min(optMaxDistance, maxDistance) // Only reduce it since 1000 ly is maximum routable
            }
        }

        if distance >= 100 {
            distance /= 1000.0 // Assume accidental entry in ly instead of kly.
        }

        let N = floor(maxDistance / jumpRange)
        let M = N * jumpRange
        let estRange = M - ((N / 4) + (distance * 2))
        if estRange <= 0 {
            message.replyToChannel("Error: Calculation resulted in a negative distance. Please check your input.");
            return
        }
        let marginOfError = estRange*0.0055
        message.replyToChannel(String(format: "Estimated plot range should be around **%.0f ly** - check range *%.0f to %.0f ly*", estRange, floor(estRange-marginOfError), ceil(estRange+marginOfError)))
    }

}
