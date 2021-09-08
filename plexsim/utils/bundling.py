# from datashader.bundling
# copied here as datashader was broken
class hammer_bundle(connect_edges):
    """
    Iteratively group edges and return as paths suitable for datashading.

    Breaks each edge into a path with multiple line segments, and
    iteratively curves this path to bundle edges into groups.
    """

    initial_bandwidth = param.Number(
        default=0.05,
        bounds=(0.0, None),
        doc="""
        Initial value of the bandwidth....""",
    )

    decay = param.Number(
        default=0.7,
        bounds=(0.0, 1.0),
        doc="""
        Rate of decay in the bandwidth value, with 1.0 indicating no decay.""",
    )

    iterations = param.Integer(
        default=4,
        bounds=(1, None),
        doc="""
        Number of passes for the smoothing algorithm""",
    )

    batch_size = param.Integer(
        default=20000,
        bounds=(1, None),
        doc="""
        Number of edges to process together""",
    )

    tension = param.Number(
        default=0.3,
        bounds=(0, None),
        precedence=-0.5,
        doc="""
        Exponential smoothing factor to use when smoothing""",
    )

    accuracy = param.Integer(
        default=500,
        bounds=(1, None),
        precedence=-0.5,
        doc="""
        Number of entries in table for...""",
    )

    advect_iterations = param.Integer(
        default=50,
        bounds=(0, None),
        precedence=-0.5,
        doc="""
        Number of iterations to move edges along gradients""",
    )

    min_segment_length = param.Number(
        default=0.008,
        bounds=(0, None),
        precedence=-0.5,
        doc="""
        Minimum length (in data space?) for an edge segment""",
    )

    max_segment_length = param.Number(
        default=0.016,
        bounds=(0, None),
        precedence=-0.5,
        doc="""
        Maximum length (in data space?) for an edge segment""",
    )

    weight = param.String(
        default="weight",
        allow_None=True,
        doc="""
        Column name for each edge weight. If None, weights are ignored.""",
    )

    def __call__(self, nodes, edges, **params):
        if skimage is None:
            raise ImportError(
                "hammer_bundle operation requires scikit-image. "
                "Ensure you install the dependency before applying "
                "bundling."
            )

        p = param.ParamOverrides(self, params)

        # Calculate min/max for coordinates
        xmin, xmax = np.min(nodes[p.x]), np.max(nodes[p.x])
        ymin, ymax = np.min(nodes[p.y]), np.max(nodes[p.y])

        # Normalize coordinates
        nodes = nodes.copy()
        nodes[p.x] = minmax_normalize(nodes[p.x], xmin, xmax)
        nodes[p.y] = minmax_normalize(nodes[p.y], ymin, ymax)

        # Convert graph into list of edge segments
        edges, segment_class = _convert_graph_to_edge_segments(nodes, edges, p)

        # This is simply to let the work split out over multiple cores
        edge_batches = list(batches(edges, p.batch_size))

        # This gets the edges split into lots of small segments
        # Doing this inside a delayed function lowers the transmission overhead
        edge_segments = [
            resample_edges(
                batch, p.min_segment_length, p.max_segment_length, segment_class.ndims
            )
            for batch in edge_batches
        ]

        for i in range(p.iterations):
            # Each step, the size of the 'blur' shrinks
            bandwidth = p.initial_bandwidth * p.decay ** (i + 1) * p.accuracy

            # If it's this small, there won't be a change anyway
            if bandwidth < 2:
                break

            # Draw the density maps and combine them
            images = [
                draw_to_surface(
                    segment, bandwidth, p.accuracy, segment_class.accumulate
                )
                for segment in edge_segments
            ]
            overall_image = sum(images)

            gradients = get_gradients(overall_image)

            # Move edges along the gradients and resample when necessary
            # This could include smoothing to adjust the amount a graph can change
            edge_segments = [
                advect_resample_all(
                    gradients,
                    segment,
                    p.advect_iterations,
                    p.accuracy,
                    p.min_segment_length,
                    p.max_segment_length,
                    segment_class,
                )
                for segment in edge_segments
            ]

        # Do a final resample to a smaller size for nicer rendering
        edge_segments = [
            resample_edges(
                segment, p.min_segment_length, p.max_segment_length, segment_class.ndims
            )
            for segment in edge_segments
        ]

        # Finally things can be sent for computation
        edge_segments = compute(*edge_segments)

        # Smooth out the graph
        for i in range(10):
            for batch in edge_segments:
                smooth(batch, p.tension, segment_class.idx, segment_class.idy)

        # Flatten things
        new_segs = []
        for batch in edge_segments:
            new_segs.extend(batch)

        # Convert list of edge segments to Pandas dataframe
        df = _convert_edge_segments_to_dataframe(new_segs, segment_class, p)

        # Denormalize coordinates
        df[p.x] = minmax_denormalize(df[p.x], xmin, xmax)
        df[p.y] = minmax_denormalize(df[p.y], ymin, ymax)

        return df
