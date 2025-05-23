import Foundation

class NetworkManager {
    private let apiKey = "sk-1a4bfeaed01945ba8e9a8bc651a2ac2d"
    private let apiURL = "https://api.deepseek.com/chat/completions"

    func sendMessage(message: String, completion: @escaping (String) -> Void) {
        guard let url = URL(string: apiURL) else {
            print("URL milena")
            return
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")

        //request body banako
        let requestBody: [String: Any] = [
            "model": "deepseek-chat",
            "messages": [
                ["role": "user", "content": message]
            ]
        ]

        // dictinoary data lai json ma convert garako
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: requestBody, options: [])
            request.httpBody = jsonData  //requestbody lai json banara pathako
        } catch {
            print("Failed to encode request body: \(error.localizedDescription)")
            return
        }

        let task = URLSession.shared.dataTask(with: request) { data, response, error in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }

            guard let data = data else {
                print("No data received")
                return
            }

            // raw response data print gareko
            if let rawResponse = String(data: data, encoding: .utf8) {
                print("Raw API Response: \(rawResponse)")
            }

            // Parse JSON response
            do {
                if let json = try JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                    print("Parsed JSON: \(json)")

                    if let choices = json["choices"] as? [[String: Any]],
                       let firstChoice = choices.first,
                       let messageDict = firstChoice["message"] as? [String: Any],
                       let reply = messageDict["content"] as? String {
                        if(reply.isEmpty){
                            completion("Server is busy. Please try again later.")
                            return
                        }
                        completion(reply)
                    } else {
                        print("Key 'message.content' not found in response")
                    }
                }
            } catch {
                print("Failed to parse response as JSON: \(error.localizedDescription)")
            }
        }
        task.resume()
    }
}
