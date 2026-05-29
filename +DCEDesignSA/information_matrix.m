    function Info_mats = information_matrix(xmat, pts, wts, cset)
    % GENINFOMATS Compute Fisher information matrices for all parameter draws.
        nsamples = length(wts);
        Info_mats = zeros(size(xmat, 2), size(xmat, 2), nsamples);
        for idx = 1:nsamples
            b = pts(:, idx);
            info = DCEDesignSA.InfoMNL(xmat, b, cset);
            Info_mats(:, :, idx) = info;
        end
    end