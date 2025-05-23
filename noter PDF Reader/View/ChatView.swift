import SwiftUI

struct ChatView: View {
    @StateObject private var viewModel = ChatViewModel()

    var body: some View {
        NavigationView {

            VStack {
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(viewModel.messages) { message in
                            HStack {
                                if message.isUser {
                                    Spacer()
                                    Text(message.text)
                                        .padding()
                                        .background(Color.orange)
                                        .foregroundColor(.white)
                                        .cornerRadius(10)
                                } else {
                                    Text(message.text)
                                        .padding()
                                        .background(Color.gray.opacity(0.2))
                                        .foregroundColor(.black)
                                        .cornerRadius(10)
                                    Spacer()
                                }
                            }
                        }
                    }
                }
                .padding(.horizontal)

                HStack {
                    TextField("Type a message...", text: $viewModel.userInput)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .padding()

                    Button(action: viewModel.sendMessage) {
                        Image(systemName: "paperplane.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                    }
                }
                .padding()


            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    Text("JK Bot")
                        .font(.title)
                        .fontWeight(.bold)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        viewModel.messages = [] //purano chat haru hatauna lai
                    }) {
                        Image(systemName: "plus")
                            .font(.title2)
                            .foregroundColor(.orange)
                    }
                }
            }
        }


    }
}
