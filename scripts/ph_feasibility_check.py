"""
Feasibility Check: Persistent Homology for 3D Object Classification
목표: PH feature가 object class 구분에 유의미한 정보를 주는지 검증

실험 순서:
1. ModelNet40 point cloud 로드
2. 각 object에 대해 PH 계산 (H0, H1, H2)
3. Persistence diagram → vectorization (Betti curve, persistence statistics)
4. Class별 topological signature 분포 시각화
5. t-SNE로 clustering 확인
"""

import numpy as np
from pathlib import Path
import pickle
from collections import defaultdict
from tqdm import tqdm

# ============================================================
# 1. 데이터 로드 (ModelNet40 point cloud)
# ============================================================

def load_modelnet40_sample(data_dir: str, n_samples_per_class: int = 50):
    """
    ModelNet40 point cloud 샘플 로드

    다운로드: https://shapenet.cs.stanford.edu/media/modelnet40_ply_hdf5_2048.zip
    또는 torch_geometric.datasets.ModelNet 사용
    """
    try:
        import h5py

        data_path = Path(data_dir)
        all_points = []
        all_labels = []
        label_names = []

        # shape_names.txt에서 클래스명 로드
        names_file = data_path / "shape_names.txt"
        if names_file.exists():
            with open(names_file, 'r') as f:
                label_names = [line.strip() for line in f]

        # h5 파일들 로드
        for h5_file in sorted(data_path.glob("*.h5")):
            with h5py.File(h5_file, 'r') as f:
                points = f['data'][:]  # (N, 2048, 3)
                labels = f['label'][:].flatten()
                all_points.append(points)
                all_labels.append(labels)

        if all_points:
            all_points = np.concatenate(all_points, axis=0)
            all_labels = np.concatenate(all_labels, axis=0)

            # 클래스별 샘플링
            sampled_points = []
            sampled_labels = []
            for label in np.unique(all_labels):
                indices = np.where(all_labels == label)[0]
                selected = indices[:n_samples_per_class]
                sampled_points.append(all_points[selected])
                sampled_labels.extend([label] * len(selected))

            return np.concatenate(sampled_points), np.array(sampled_labels), label_names

    except ImportError:
        print("h5py not installed. Using synthetic data for demo.")

    return None, None, None


def generate_synthetic_objects(n_samples: int = 200):
    """
    실제 데이터 없을 때 테스트용 synthetic objects
    - Sphere: β0=1, β1=0, β2=1 (cavity)
    - Torus: β0=1, β1=2, β2=1 (hole)
    - Cube: β0=1, β1=0, β2=0
    - Mug (cylinder + handle): β0=1, β1=1, β2=0
    """
    objects = []
    labels = []
    label_names = ['sphere', 'torus', 'cube', 'mug']

    n_per_class = n_samples // 4
    n_points = 200  # 500 -> 200으로 줄임 (PH 계산 속도)

    for i in range(n_per_class):
        noise = np.random.randn(n_points, 3) * 0.02

        # Sphere
        phi = np.random.uniform(0, 2*np.pi, n_points)
        theta = np.random.uniform(0, np.pi, n_points)
        r = 1.0
        sphere = np.stack([
            r * np.sin(theta) * np.cos(phi),
            r * np.sin(theta) * np.sin(phi),
            r * np.cos(theta)
        ], axis=1) + noise
        objects.append(sphere)
        labels.append(0)

        # Torus
        R, r = 1.0, 0.3  # major, minor radius
        u = np.random.uniform(0, 2*np.pi, n_points)
        v = np.random.uniform(0, 2*np.pi, n_points)
        torus = np.stack([
            (R + r*np.cos(v)) * np.cos(u),
            (R + r*np.cos(v)) * np.sin(u),
            r * np.sin(v)
        ], axis=1) + noise
        objects.append(torus)
        labels.append(1)

        # Cube
        face = np.random.randint(0, 6, n_points)
        cube = np.random.uniform(-1, 1, (n_points, 3))
        for j in range(n_points):
            axis = face[j] // 2
            side = (face[j] % 2) * 2 - 1
            cube[j, axis] = side
        cube += noise
        objects.append(cube)
        labels.append(2)

        # Mug (simplified: cylinder + torus handle)
        n_body = n_points * 3 // 4
        n_handle = n_points - n_body

        # Cylinder body
        theta_c = np.random.uniform(0, 2*np.pi, n_body)
        z_c = np.random.uniform(0, 1.5, n_body)
        r_c = 0.5
        body = np.stack([r_c * np.cos(theta_c), r_c * np.sin(theta_c), z_c], axis=1)

        # Handle (partial torus)
        u_h = np.random.uniform(-np.pi/2, np.pi/2, n_handle)
        v_h = np.random.uniform(0, 2*np.pi, n_handle)
        R_h, r_h = 0.3, 0.08
        handle = np.stack([
            0.5 + (R_h + r_h*np.cos(v_h)) * np.cos(u_h),
            (R_h + r_h*np.cos(v_h)) * np.sin(u_h),
            0.75 + r_h * np.sin(v_h)
        ], axis=1)

        mug = np.vstack([body, handle]) + noise[:len(body)+len(handle)]
        objects.append(mug)
        labels.append(3)

    return objects, np.array(labels), label_names


# ============================================================
# 2. Persistent Homology 계산
# ============================================================

def compute_persistence_features(points: np.ndarray, max_edge_length: float = 0.5):
    """
    Point cloud에서 Persistent Homology 계산

    Returns:
        dict: {
            'betti_0': Betti-0 (connected components),
            'betti_1': Betti-1 (loops),
            'betti_2': Betti-2 (voids),
            'persistence_stats': 통계량 (mean, max persistence 등)
        }
    """
    try:
        import gudhi
    except ImportError:
        raise ImportError("GUDHI not installed. Run: pip install gudhi")

    # Normalize point cloud
    points = points - points.mean(axis=0)
    points = points / (np.max(np.abs(points)) + 1e-8)

    # Rips complex
    rips = gudhi.RipsComplex(points=points, max_edge_length=max_edge_length)
    simplex_tree = rips.create_simplex_tree(max_dimension=3)

    # Compute persistence
    persistence = simplex_tree.persistence()

    # Extract features
    features = {
        'betti_0': 0, 'betti_1': 0, 'betti_2': 0,
        'persistence_0': [], 'persistence_1': [], 'persistence_2': [],
        'total_persistence_0': 0, 'total_persistence_1': 0, 'total_persistence_2': 0,
        'max_persistence_0': 0, 'max_persistence_1': 0, 'max_persistence_2': 0,
    }

    for dim, (birth, death) in persistence:
        if death == float('inf'):
            death = max_edge_length  # Cap infinite death times

        persistence_val = death - birth

        if dim == 0:
            features['persistence_0'].append(persistence_val)
            features['betti_0'] += 1 if persistence_val > 0.1 else 0
        elif dim == 1:
            features['persistence_1'].append(persistence_val)
            features['betti_1'] += 1 if persistence_val > 0.1 else 0
        elif dim == 2:
            features['persistence_2'].append(persistence_val)
            features['betti_2'] += 1 if persistence_val > 0.1 else 0

    # Statistics
    for dim in [0, 1, 2]:
        pers = features[f'persistence_{dim}']
        if pers:
            features[f'total_persistence_{dim}'] = sum(pers)
            features[f'max_persistence_{dim}'] = max(pers)
            features[f'mean_persistence_{dim}'] = np.mean(pers)
            features[f'std_persistence_{dim}'] = np.std(pers)

    return features


def extract_feature_vector(ph_features: dict) -> np.ndarray:
    """PH features를 고정 크기 벡터로 변환"""
    return np.array([
        ph_features.get('betti_0', 0),
        ph_features.get('betti_1', 0),
        ph_features.get('betti_2', 0),
        ph_features.get('total_persistence_0', 0),
        ph_features.get('total_persistence_1', 0),
        ph_features.get('total_persistence_2', 0),
        ph_features.get('max_persistence_0', 0),
        ph_features.get('max_persistence_1', 0),
        ph_features.get('max_persistence_2', 0),
        ph_features.get('mean_persistence_0', 0),
        ph_features.get('mean_persistence_1', 0),
        ph_features.get('mean_persistence_2', 0),
    ])


# ============================================================
# 3. 분석 및 시각화
# ============================================================

def analyze_topological_features(objects, labels, label_names):
    """모든 object에 대해 PH 계산 및 분석"""
    print(f"Computing PH for {len(objects)} objects...")

    all_features = []
    all_ph_raw = []

    for obj in tqdm(objects):
        try:
            ph = compute_persistence_features(obj)
            all_ph_raw.append(ph)
            all_features.append(extract_feature_vector(ph))
        except Exception as e:
            print(f"Error: {e}")
            all_ph_raw.append({})
            all_features.append(np.zeros(12))

    features_array = np.array(all_features)

    # Class별 통계
    print("\n" + "="*60)
    print("Class별 Topological Signature 통계")
    print("="*60)

    for label_id in np.unique(labels):
        mask = labels == label_id
        class_features = features_array[mask]
        name = label_names[label_id] if label_id < len(label_names) else f"Class_{label_id}"

        print(f"\n[{name}] (n={mask.sum()})")
        print(f"  β0: {class_features[:, 0].mean():.2f} ± {class_features[:, 0].std():.2f}")
        print(f"  β1: {class_features[:, 1].mean():.2f} ± {class_features[:, 1].std():.2f}")
        print(f"  β2: {class_features[:, 2].mean():.2f} ± {class_features[:, 2].std():.2f}")
        print(f"  Max Pers H1: {class_features[:, 7].mean():.3f} ± {class_features[:, 7].std():.3f}")

    return features_array, all_ph_raw


def visualize_results(features_array, labels, label_names, save_path: str = None):
    """t-SNE 시각화 및 분석 플롯"""
    try:
        import matplotlib.pyplot as plt
        from sklearn.manifold import TSNE
        from sklearn.preprocessing import StandardScaler
    except ImportError:
        print("matplotlib or sklearn not installed. Skipping visualization.")
        return

    # Normalize features
    scaler = StandardScaler()
    features_norm = scaler.fit_transform(features_array)

    # t-SNE
    print("\nRunning t-SNE...")
    tsne = TSNE(n_components=2, random_state=42, perplexity=30)
    features_2d = tsne.fit_transform(features_norm)

    # Plot
    fig, axes = plt.subplots(1, 2, figsize=(14, 6))

    # t-SNE plot
    ax1 = axes[0]
    for label_id in np.unique(labels):
        mask = labels == label_id
        name = label_names[label_id] if label_id < len(label_names) else f"Class_{label_id}"
        ax1.scatter(features_2d[mask, 0], features_2d[mask, 1], label=name, alpha=0.7)
    ax1.set_title("t-SNE of Topological Features")
    ax1.legend()
    ax1.set_xlabel("t-SNE 1")
    ax1.set_ylabel("t-SNE 2")

    # Betti number distribution
    ax2 = axes[1]
    x = np.arange(len(label_names))
    width = 0.25

    betti_0_means = [features_array[labels == i, 0].mean() for i in range(len(label_names))]
    betti_1_means = [features_array[labels == i, 1].mean() for i in range(len(label_names))]
    betti_2_means = [features_array[labels == i, 2].mean() for i in range(len(label_names))]

    ax2.bar(x - width, betti_0_means, width, label='β0 (components)')
    ax2.bar(x, betti_1_means, width, label='β1 (loops)')
    ax2.bar(x + width, betti_2_means, width, label='β2 (voids)')
    ax2.set_xticks(x)
    ax2.set_xticklabels(label_names, rotation=45, ha='right')
    ax2.set_title("Average Betti Numbers by Class")
    ax2.legend()
    ax2.set_ylabel("Count")

    plt.tight_layout()

    if save_path:
        plt.savefig(save_path, dpi=150, bbox_inches='tight')
        print(f"Saved to {save_path}")
    else:
        plt.show()


def classification_test(features_array, labels):
    """간단한 분류 테스트로 PH feature의 discriminative power 확인"""
    try:
        from sklearn.model_selection import cross_val_score
        from sklearn.ensemble import RandomForestClassifier
        from sklearn.preprocessing import StandardScaler
    except ImportError:
        print("sklearn not installed. Skipping classification test.")
        return

    scaler = StandardScaler()
    features_norm = scaler.fit_transform(features_array)

    clf = RandomForestClassifier(n_estimators=100, random_state=42)
    scores = cross_val_score(clf, features_norm, labels, cv=5)

    print("\n" + "="*60)
    print("Classification Test (Random Forest, 5-fold CV)")
    print("="*60)
    print(f"Accuracy: {scores.mean():.3f} ± {scores.std():.3f}")
    print(f"(Random baseline: {1/len(np.unique(labels)):.3f})")


# ============================================================
# Main
# ============================================================

def main():
    import argparse
    parser = argparse.ArgumentParser()
    parser.add_argument('--data_dir', type=str, default=None,
                        help='Path to ModelNet40 h5 files')
    parser.add_argument('--n_samples', type=int, default=200,
                        help='Number of samples for synthetic data')
    parser.add_argument('--save_path', type=str, default='ph_analysis.png',
                        help='Path to save visualization')
    args = parser.parse_args()

    # Load or generate data
    if args.data_dir:
        objects, labels, label_names = load_modelnet40_sample(args.data_dir)
        if objects is None:
            print("Failed to load ModelNet40. Using synthetic data.")
            objects, labels, label_names = generate_synthetic_objects(args.n_samples)
    else:
        print("No data_dir provided. Using synthetic data for demonstration.")
        objects, labels, label_names = generate_synthetic_objects(args.n_samples)

    print(f"Loaded {len(objects)} objects, {len(label_names)} classes: {label_names}")

    # Analyze
    features_array, all_ph_raw = analyze_topological_features(objects, labels, label_names)

    # Visualize
    visualize_results(features_array, labels, label_names, args.save_path)

    # Classification test
    classification_test(features_array, labels)

    print("\n✓ Feasibility check complete!")


if __name__ == "__main__":
    main()
