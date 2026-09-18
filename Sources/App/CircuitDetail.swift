import SwiftUI
import UIKit

struct CircuitDetailSections: View {
    @EnvironmentObject var m: AppModel
    let race: Race
    @State private var showMap = false
    var profile: CircuitProfile? { CircuitCatalog.profiles[race.circuitID] }
    var body: some View {
        if let p = profile {
            VStack(alignment: .leading, spacing: 18) {
                HStack {
                    VStack(alignment: .leading, spacing: 6) {
                        Eyebrow(text: "CIRCUIT GUIDE")
                        Text(race.circuitTitle(m.zh)).font(.title2.bold())
                    }
                    Spacer()
                    Image(systemName: "flag.checkered").font(.title2).foregroundStyle(RWStyle.orange)
                }
                Panel {
                    VStack(alignment: .leading, spacing: 16) {
                        Text(m.t("赛道档案 · ", "CIRCUIT PROFILE · ") + String(p.sourceYear)).font(.caption.bold()).foregroundStyle(.secondary)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], alignment: .leading, spacing: 22) {
                            metric(m.t("正赛圈数", "Race laps"), p.laps, m.t("圈", "laps"))
                            metric(m.t("单圈长度", "Circuit length"), p.length, "km")
                            metric(m.t("比赛总距离", "Race distance"), p.distance, "km")
                            metric(m.t("首次 F1 分站", "First F1 Grand Prix"), p.firstGP, "")
                        }
                        Text(m.t("以上为官网 \(p.sourceYear) 年资料中的计划正赛参数，不是实际完赛距离。赛道布局或赛制变化时可能调整。", "These are planned race figures from the official \(p.sourceYear) profile, not the distance actually completed. Layouts and race formats can change.")).font(.caption).foregroundStyle(.secondary)
                        if p.sourceYear != race.season {
                            Label(m.t("所选赛季为 \(race.season)，此处展示 \(p.sourceYear) 年参考资料。", "Selected season: \(race.season). Reference profile: \(p.sourceYear)."), systemImage: "info.circle").font(.caption).foregroundStyle(.orange)
                        }
                    }
                }
                Panel {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack { Text(m.t("赛道路线与计时段", "Layout & timing sectors")).font(.headline); Spacer(); Image(systemName: "arrow.up.left.and.arrow.down.right").foregroundStyle(RWStyle.orange) }
                        Button { showMap = true } label: {
                            if let image = circuitImage(p) {
                                Image(uiImage: image).resizable().scaledToFit().padding(10).background(.white, in: RoundedRectangle(cornerRadius: 12))
                            } else {
                                Label(m.t("地图未能载入，查看官网原图", "Map unavailable; open the original"), systemImage: "map").padding()
                            }
                        }.buttonStyle(.plain).accessibilityLabel(m.t("放大官方赛道地图", "Enlarge official circuit map"))
                        if !p.sectorsLabeled {
                            HStack(spacing: 18) {
                                sector("S1", .red); sector("S2", .cyan); sector("S3", .yellow)
                            }
                        }
                        Text(p.sectorsLabeled
                             ? m.t("图中的 SECTOR 1／2／3 对应三个计时段。轻点地图后可双指缩放、拖动查看。", "SECTOR 1 / 2 / 3 identify the timing sectors. Tap the map, then pinch to zoom and drag to explore.")
                             : m.t("这张官网原图以红、蓝、黄区分第一、第二、第三计时段。轻点后可缩放查看；起终点及行驶方向见图中标记。", "This official map uses red, blue and yellow for sectors 1, 2 and 3. Tap to zoom; the start/finish and direction are marked on the map.")).font(.caption).foregroundStyle(.secondary)
                        Text(m.t("官方原图 · \(p.sourceYear) · 保留英文标注", "Official original · \(p.sourceYear) · English labels retained")).font(.caption2).foregroundStyle(.secondary)
                        Link(m.t("www.formula1.com · 查看地图来源", "www.formula1.com · Map source"), destination: URL(string: p.sourceURL)!).font(.caption)
                    }
                }
                article(m.t("赛道与 F1 的历史", "The circuit & F1"), p.history(m.zh), icon: "clock.arrow.circlepath")
                article(m.t("认识这里", "Explore the destination"), p.region(m.zh), icon: "globe.asia.australia")
                VStack(alignment: .leading, spacing: 8) {
                    Text(m.t("资料来源：F1 官网；介绍为摘要与中文翻译。", "Source: the F1 website. Descriptions are summaries and Chinese translations.")).font(.caption).foregroundStyle(.secondary)
                    Text(m.t("核对日期：", "Checked: ") + p.checkedAt).font(.caption2).foregroundStyle(.secondary)
                    Link("www.formula1.com", destination: URL(string: p.sourceURL)!).font(.caption.bold())
                    Text(m.t("地图版权归相关权利人所有。比赛周是独立、非官方车迷应用。", "Map rights belong to their respective owners. Tracktion is an independent, unofficial fan app.")).font(.caption2).foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showMap) {
                NavigationStack {
                    Group {
                        if let image = circuitImage(p) { ZoomableCircuitMap(image: image) }
                        else { ContentUnavailableView(m.t("地图暂不可用", "Map unavailable"), systemImage: "map") }
                    }
                    .background(.white).ignoresSafeArea(edges: .bottom)
                    .navigationTitle(race.circuitTitle(m.zh)).navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarLeading) { Link(m.t("官网原图", "Original"), destination: URL(string: p.mapURL)!) }
                        ToolbarItem(placement: .topBarTrailing) { Button(m.t("完成", "Done")) { showMap = false } }
                    }
                }.environment(\.locale, Locale(identifier: m.zh ? "zh_Hans" : "en"))
            }
        } else {
            Panel { Label(m.t("这条赛道的官方详情尚未收录。", "An official profile for this circuit has not been added yet."), systemImage: "info.circle").font(.subheadline) }
        }
    }
    func metric(_ title: String, _ value: String, _ unit: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            (Text(value).font(.system(.title2, design: .rounded, weight: .bold)) + Text(" " + unit).font(.caption)).minimumScaleFactor(0.75).lineLimit(1)
        }
    }
    func sector(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 5) { Circle().fill(color).frame(width: 9,height: 9); Text(label).font(.caption.bold()) }
    }
    func article(_ title: String, _ text: String, icon: String) -> some View {
        Panel { VStack(alignment: .leading, spacing: 12) { Label(title, systemImage: icon).font(.headline); Text(text).font(.subheadline).lineSpacing(5).textSelection(.enabled) } }
    }
    func circuitImage(_ p: CircuitProfile) -> UIImage? {
        guard let url = Bundle.main.url(forResource: p.mapFile, withExtension: nil, subdirectory: "Circuits") else { return nil }
        return UIImage(contentsOfFile: url.path)
    }
}

/// UIScrollView supplies real zooming and panning rather than scaling a clipped SwiftUI image.
struct ZoomableCircuitMap: UIViewRepresentable {
    let image: UIImage
    func makeUIView(context: Context) -> CircuitZoomView { CircuitZoomView(image: image) }
    func updateUIView(_ view: CircuitZoomView, context: Context) {}
}
final class CircuitZoomView: UIScrollView, UIScrollViewDelegate {
    private let imageView: UIImageView
    private var previousSize: CGSize = .zero
    init(image: UIImage) {
        imageView = UIImageView(image: image)
        super.init(frame: .zero)
        delegate = self; backgroundColor = .white
        imageView.frame = CGRect(origin: .zero, size: image.size)
        addSubview(imageView); contentSize = image.size
        let tap = UITapGestureRecognizer(target: self, action: #selector(doubleTap(_:)))
        tap.numberOfTapsRequired = 2; addGestureRecognizer(tap)
        imageView.accessibilityLabel = "Official circuit map: Sector 1, Sector 2, Sector 3"
        imageView.isAccessibilityElement = true
    }
    required init?(coder: NSCoder) { fatalError("init(coder:) has not been implemented") }
    override func layoutSubviews() {
        super.layoutSubviews()
        guard bounds.width > 0, bounds.height > 0, let image = imageView.image else { return }
        if previousSize != bounds.size {
            previousSize = bounds.size
            let fit = min(bounds.width / image.size.width, bounds.height / image.size.height)
            minimumZoomScale = fit; maximumZoomScale = fit * 6; zoomScale = fit
        }
        contentInset = UIEdgeInsets(top: max(0,(bounds.height-contentSize.height)/2), left: max(0,(bounds.width-contentSize.width)/2), bottom: 0, right: 0)
    }
    func viewForZooming(in scrollView: UIScrollView) -> UIView? { imageView }
    func scrollViewDidZoom(_ scrollView: UIScrollView) { setNeedsLayout() }
    @objc private func doubleTap(_ gesture: UITapGestureRecognizer) {
        if zoomScale > minimumZoomScale * 1.1 { setZoomScale(minimumZoomScale, animated: true) }
        else {
            let scale = min(maximumZoomScale, minimumZoomScale * 3)
            let point = gesture.location(in: imageView)
            let size = CGSize(width: bounds.width / scale, height: bounds.height / scale)
            zoom(to: CGRect(x: point.x-size.width/2, y: point.y-size.height/2, width: size.width, height: size.height), animated: true)
        }
    }
}
