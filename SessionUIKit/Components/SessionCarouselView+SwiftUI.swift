// Copyright © 2023 Rangeproof Pty Ltd. All rights reserved.

import SwiftUI

public struct SessionCarouselView_SwiftUI: View {
    @Binding var index: Int
    var contentInfos: [Color]
    let numberOfPages: Int
    
    public init(index: Binding<Int>, contentInfos: [Color]) {
        self._index = index
        self.contentInfos = contentInfos
        self.numberOfPages = contentInfos.count
        
        let first = self.contentInfos.first!
        let last = self.contentInfos.last!
        self.contentInfos.append(first)
        self.contentInfos.insert(last, at: 0)
    }
    
    public var body: some View {
        HStack(spacing: 0) {
            ArrowView(index: $index, numberOfPages: numberOfPages, type: .decrement)
                .zIndex(1)
            
            PageView(index: $index, numberOfPages: self.numberOfPages) {
                ForEach(self.contentInfos, id: \.self) { color in
                    Rectangle()
                        .foregroundColor(color)
                }
            }
            .aspectRatio(1, contentMode: .fit)
            
            ArrowView(index: $index, numberOfPages: numberOfPages, type: .increment)
                .zIndex(1)
        }
    }
}

struct ArrowView: View {
    @Binding var index: Int
    let numberOfPages: Int
    let maxIndex: Int
    let type: ArrowType
    
    enum ArrowType {
        case increment
        case decrement
    }
    
    init(index: Binding<Int>, numberOfPages: Int, type: ArrowType) {
        self._index = index
        self.numberOfPages = numberOfPages
        self.maxIndex = numberOfPages + 1
        self.type = type
    }
    
    var body: some View {
        let imageName = self.type == .decrement ? "chevron.left" : "chevron.right"
        Button {
            print("Tap")
            if self.type == .decrement {
                decrement()
            } else {
                increment()
            }
        } label: {
            Image(systemName: imageName)
                .font(.system(size: 20))
                .foregroundColor(.white)
                .frame(width: 30, height: 30)
        }
    }
    
    func decrement() {
        withAnimation(.easeOut) {
            self.index -= 1
        }
        
        if self.index == 0 {
            self.index = self.maxIndex - 1
        }
    }
    
    func increment() {
        withAnimation(.easeOut) {
            self.index += 1
        }
        
        if self.index == self.maxIndex {
            self.index = 1
        }
    }
}

struct PageView<Content>: View where Content: View {
    @Binding var index: Int
    let numberOfPages: Int
    let maxIndex: Int
    let content: () -> Content

    @State private var offset = CGFloat.zero
    @State private var dragging = false

    init(index: Binding<Int>, numberOfPages: Int, @ViewBuilder content: @escaping () -> Content) {
        self._index = index
        self.numberOfPages = numberOfPages
        self.content = content
        self.maxIndex = numberOfPages + 1
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            GeometryReader { geometry in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        self.content()
                        .frame(width: geometry.size.width, height: geometry.size.height)
                    }
                }
                .content.offset(x: self.offset(in: geometry), y: 0)
                .frame(width: geometry.size.width, alignment: .leading)
                .clipShape(RoundedRectangle(cornerRadius: 15))
                .gesture(
                    DragGesture(coordinateSpace: .local)
                        .onChanged { value in
                            self.dragging = true
                            self.offset = -CGFloat(self.index) * geometry.size.width + value.translation.width
                        }
                        .onEnded { value in
                            let predictedEndOffset = -CGFloat(self.index) * geometry.size.width + value.predictedEndTranslation.width
                            let predictedIndex = Int(round(predictedEndOffset / -geometry.size.width))
                            self.index = self.clampedIndex(from: predictedIndex)
                            withAnimation(.easeOut) {
                                self.dragging = false
                            }
                            switch self.index {
                                case 0: self.index = self.maxIndex - 1
                                case self.maxIndex: self.index = 1
                                default: break
                            }
                        }
                )
            }
            .clipped()

            PageControl(index: $index, maxIndex: numberOfPages - 1)
                .padding(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
        }
    }

    func offset(in geometry: GeometryProxy) -> CGFloat {
        if self.dragging {
            return max(min(self.offset, 0), -CGFloat(self.maxIndex) * geometry.size.width)
        } else {
            return -CGFloat(self.index) * geometry.size.width
        }
    }

    func clampedIndex(from predictedIndex: Int) -> Int {
        let newIndex = min(max(predictedIndex, self.index - 1), self.index + 1)
        guard newIndex >= 0 else { return 0 }
        guard newIndex <= maxIndex else { return maxIndex }
        return newIndex
    }
}

struct PageControl: View {
    @Binding var index: Int
    let maxIndex: Int

    var body: some View {
        ZStack {
            Capsule()
                .foregroundColor(.init(white: 0, opacity: 0.4))
            HStack(spacing: 4) {
                ForEach(0...maxIndex, id: \.self) { index in
                    Circle()
                        .fill(index == ((self.index - 1) % (self.maxIndex + 1)) ? Color.white : Color.gray)
                        .frame(width: 6.62, height: 6.62)
                }
            }
            .padding(6)
        }
        .fixedSize(horizontal: true, vertical: true)
        .frame(
            maxWidth: .infinity,
            maxHeight: 19
        )
    }
}

struct SessionCarouselView_SwiftUI_Previews: PreviewProvider {
    @State static var index = 1
    static var previews: some View {
        ZStack {
            if #available(iOS 14.0, *) {
                Color.black.ignoresSafeArea()
            } else {
                Color.black
            }
            
            SessionCarouselView_SwiftUI(index: $index, contentInfos: [.red, .orange, .blue])
        }
    }
}
